#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

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
            if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get --no-headers ${nncp} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}') == 'True' ]]; then
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

    echo ">>>> Wait until NMState is ready for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "240" ]; do
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} -n openshift-nmstate get pod | grep -i running | wc -l) -ge 1 ]]; then
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

    echo ">>>> Wait until MetalLB is ready for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "240" ]; do
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} -n metallb get pod | grep -i running | wc -l) -ge 1 ]]; then
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

source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Deploying NMState and MetalLB operators"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0
for spoke in ${ALLSPOKES}; do
    echo ">>>> Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}

    echo ">>>> Deploying NMState pre-reqs for ${spoke}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-NMS-Namespace.yaml
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-NMS-OperatorGroup.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-NMS-Subscription.yaml
    sleep 10

    echo ">>>> Deploying MetalLB pre-reqs for ${spoke}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-MLB-Namespace.yaml
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-MLB-OperatorGroup.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-MLB-Subscription.yaml
    sleep 10

    verify_ops $spoke
    
    echo ">>>> Waiting for subscription and crd on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "120" ]; do
        echo KUBESPOKE=${SPOKE_KUBECONFIG}
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep nmstates.nmstate.io | wc -l) -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Waiting for CRD nmstates.nmstate.io to be created"
        sleep 5
        timeout=$((timeout + 5))
    done
    if [ "$ready" == "false" ]; then
        echo timeout waiting for CRD nmstates.nmstate.io
        exit 1
    fi

    echo ">>>> Deploying NMState Operand for ${spoke}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/04-NMS-Operand.yaml
    sleep 2
    for dep in {nmstate-cert-manager,nmstate-operator,nmstate-webhook}; do
        export KUBECONFIG=${SPOKE_KUBECONFIG}
        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n openshift-nmstate ${dep}
        export KUBECONFIG=${KUBECONFIG_HUB}
    done

    for master in 0 1 2; do
        export NODENAME=kubeframe-spoke-${index}-master-${master}
        export NIC_EXT_DHCP=$(yq e ".spokes[\$i].${spoke}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})
        render_file manifests/nncp.yaml
    done
    let index++
done

sleep 40

for spoke in ${ALLSPOKES}; do
    verify_cluster ${spoke}
done
