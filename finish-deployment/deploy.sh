#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${1} secret/${1}-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

function render_file() {
    SOURCE_FILE=${1}
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        echo ">>>> Applying renderized source file: ${SOURCE_FILE}"
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function verify_cluster() {
    cluster=${1}
    echo ">>>> Verifying Spoke cluster: ${cluster}"
    echo ">>>> Extract Kubeconfig for ${cluster}"
    extract_kubeconfig ${cluster}

    echo ">>>> Wait until NNCP are Available for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    for a in {0..2}; do
        for nncp in $(oc --kubeconfig=${SPOKE_KUBECONFIG} get nncp --no-headers -o name); do
            if [[ $(oc get --no-headers ${nncp} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}') == 'True' ]]; then
                echo ">>>> NNCP is in Available state"
                break
            fi
        done
        sleep 5
    done
}

function verify_ops() {
    cluster=${1}
    echo ">>>> Verifying Spoke cluster: ${cluster}"
    echo ">>>> Extract Kubeconfig for ${cluster}"
    extract_kubeconfig ${cluster}

    echo ">>>> Wait until nmstate ready for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "240" ]; do
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} -n openshift-nmstate get pod | grep -i running | wc -l) -gt 6 ]]; then
            ready=true
            break
        fi
        sleep 1
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "timeout waiting for nmstate pods "
        exit 1
    fi

    echo ">>>> Wait until metallb ready for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "240" ]; do
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} -n metallb get pod | grep -i running | wc -l) -eq 1 ]]; then
            ready=true
            break
        fi
        sleep 1
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "timeout waiting for MetalLB pods"
        exit 1
    fi
}

function dettach_cluster() {
    cluster=${1}
    echo ">>>> Detaching Spoke cluster: ${cluster}"
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${cluster}
}

source ${WORKDIR}/shared-utils/common.sh 

echo ">>>> Deploying NNCP Config"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0
for spoke in ${ALLSPOKES}; do
    verify_ops $spoke
    # METALLB_IP=$(yq e ".spokes[$i].${spoke}.metallb_ip" ${SPOKES_FILE})
    # kubeframe-spoke-${i}-master-${master}
    echo ">>>> Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}
    echo ">>>> Deploying NMState Operand for ${spoke}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/nmstate.yaml
    sleep 2
    for dep in {nmstate-cert-manager,nmstate-operatornmstate-webhook}; do
        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n openshift-nmstate ${dep}
    done

    for master in 0 1 2; do
        export NODENAME=kubeframe-spoke-${index}-master-${master}
        export NIC_EXT_DHCP=$(yq e ".spokes[\$i].${spoke}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})
        render_file manifests/nncp.yaml
        sleep 10
    done
    let index++
done

sleep 40

for spoke in ${ALLSPOKES}; do
    verify_cluster ${spoke}
    #dettach_cluster ${spoke}
done
