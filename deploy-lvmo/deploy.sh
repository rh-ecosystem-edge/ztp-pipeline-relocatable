#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function render_file() {
    SOURCE_FILE=${1}
    if [[ ${#} -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function extract_vars() {
    # Extract variables from config file
    DISKS_PATH=${1}
    raw_disks=$(yq eval "${DISKS_PATH}" "${EDGECLUSTERS_FILE}" | sed s/null//)
    disks=$(echo ${raw_disks} | tr -d '\ ' | sed 's/-/,/g' | sed 's/,*//' | sed 's/,*//')
    disks_count=$(echo ${disks} | sed 's/,/\n/g' | wc -l)

    for node in $(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes -o name | cut -f2 -d/); do
        nodes+="${node},"
    done

    nodes=$(echo ${nodes%*,})

    # Final Variables
    export CHANGEME_NODES="[${nodes}]"
    export CHANGEME_DEVICES="[${disks}]"
    export CHANGEME_STORAGE_DEVICE_SET_COUNT="${disks_count}"
}

if ! ./verify.sh; then
    echo ">>>> Modify files to replace with pipeline info gathered"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    sed -i "s/CHANGEME/$OC_ODF_VERSION/g" manifests/03-LVMO-Subscription.yaml
    sed -i "s/CATALOG_SOURCE/ztpfw-catalog/g" manifests/03-LVMO-Subscription.yaml

    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    index=0
    for edgecluster in ${ALLEDGECLUSTERS}; do
        # wipe disks on nodes 
        wipe_edge_disks

        NUM_M=$(yq e ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l | xargs)

        echo ">>>> Deploy manifests to install LVMO: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${edgecluster}"
        extract_kubeconfig_common ${edgecluster}
        echo "Filling vars for ${edgecluster}"
        extract_vars ".edgeclusters[].${edgecluster}.master0.storage_disk"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-Namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-LVMO-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-LVMO-Subscription.yaml
        sleep 5

        echo ">>>> Waiting for subscription and crd on: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        declare -a LVMOCRDS=("lvmclusters.lvm.topolvm.io" "lvmvolumegroupnodestatuses.lvm.topolvm.io" "lvmvolumegroups.lvm.topolvm.io")
        for crd in ${LVMOCRDS[@]}; do
            check_resource "crd" "${crd}" "Established" "openshift-local-storage" "${EDGE_KUBECONFIG}"
        done

        echo ">>>> Render and apply manifest to deploy LVMCluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-LVMO-LVMOCluster.yaml
        sleep 60

        echo ">>>> Waiting for: LVMCluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} -n openshift-storage lvmcluster -ojsonpath='{.items[*].status.ready}') == "true" ]]; then
                ready=true
                break
            fi
            sleep 5
            timeout=$((timeout + 1))
        done
        if [ "$ready" == "false" ]; then
            echo "timeout waiting for LVMCluster deployment..."
            exit 1
        fi
    done
    oc --kubeconfig=${EDGE_KUBECONFIG} patch storageclass odf-lvm-vg1 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    index=$((index + 1))
fi
echo ">>>>EOF"
echo ">>>>>>>"
