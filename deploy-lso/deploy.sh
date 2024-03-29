#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

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

function extract_kubeconfig() {
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $edgecluster secret/$edgecluster-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ! ./verify.sh; then
    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    index=0
    for edgecluster in ${ALLEDGECLUSTERS}; do
        wipe_edge_disks

        index=$((index + 1))

        echo ">>>> Deploy manifests to install LSO and LocalVolume: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${edgecluster}"
        extract_kubeconfig ${edgecluster}
        echo "Filling vars for ${edgecluster}"
        extract_vars ".edgeclusters[].${edgecluster}.master0.storage_disk"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-LSO-Namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-LSO-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-LSO-Subscription.yaml
        sleep 5

        echo ">>>> Waiting for subscription and crd on: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        declare -a LSOCRDS=("localvolumediscoveries.local.storage.openshift.io" "localvolumediscoveryresults.local.storage.openshift.io" "localvolumes.local.storage.openshift.io" "localvolumesets.local.storage.openshift.io")
        for crd in ${LSOCRDS[@]}; do
            check_resource "crd" "${crd}" "Established" "openshift-local-storage" "${EDGE_KUBECONFIG}"
        done

        echo ">>>> Render and apply manifests for LocalVolume on: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-LSO-LocalVolume.yaml
        sleep 20

        echo ">>>> Waiting for: LSO LocalVolume on ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        check_resource "localvolume" "localstorage-disks-block" "Available" "openshift-local-storage" "${EDGE_KUBECONFIG}"
        sleep 60
    done
fi
echo ">>>>EOF"
echo ">>>>>>>"
