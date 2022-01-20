#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function dettach_cluster() {
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Dettaching Spoke ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${cluster}
}

function clean_cluster() {
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Cleaning Spoke ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete namespace ${cluster}
}

function save_files() {
    cluster=${1}
    CLUSTER_DATA_FOLDER="~/cluster_access_data"

    mkdir -p ${RO_SPOKE_FOLDER}/${cluster}
    cp -f ${SPOKE_KUBECONFIG} ${SPOKE_KUBEADMIN_PASS} ${RO_SPOKE_FOLDER}/${cluster}

    for node in $(oc get nodes -oname)
    do
        NODE_IP=$(oc get ${node} -o jsonpath='{.status.addresses[0].address}')
        ${SSH_COMMAND} core@${NODE_IP} "mkdir ${CLUSTER_DATA_FOLDER}"
        copy_files_common "${SPOKE_KUBECONFIG}" "${NODE_IP}" "${CLUSTER_DATA_FOLDER}/"
        copy_files_common "${SPOKE_KUBEADMIN_PASS}" "${NODE_IP}" "${CLUSTER_DATA_FOLDER}/"
    done
}

function recover_spoke_files() {
    # Function to recover cluster spoke files from hub
    cluster=${1}
    echo ">> Recovering Spoke ${cluster} cluster Files"
    extract_kubeconfig_common ${cluster}
    extract_kubeadmin_pass_common ${cluster}
    save_files ${cluster}
}

source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Dettaching clusters"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
    echo ">> Cluster: ${spoke}"
    recover_spoke_files ${spoke}
    dettach_cluster ${spoke}
    clean_cluster ${spoke}
done
