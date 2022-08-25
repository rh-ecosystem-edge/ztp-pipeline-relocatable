#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function extract_kubeconfig() {
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${edgecluster} secret/${edgecluster}-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi
export NUM_M=$(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes --no-headers | grep master | wc -l)

for edgecluster in ${ALLEDGECLUSTERS}; do
    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig ${edgecluster}

    echo ">>>> Verifying ODF and StorageCluster: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Check Pods..."
    if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} pod -n openshift-storage | grep -i running | wc -l) -ne $(oc --kubeconfig=${EDGE_KUBECONFIG} get pod -n openshift-storage --no-headers | grep -v Completed | wc -l) ]]; then
        #odf in the edgecluster not exists so we need to create it
        exit 1
    fi

    echo "Check StorageCluster..."
    if [ "${NUM_M}" -eq "3" ]; then
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} StorageCluster -n openshift-storage ocs-storagecluster --no-headers | wc -l) -ne 1 ]] ; then
            exit 1
        fi
    else
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} StorageCluster -n openshift-storage mcg-storagecluster  --no-headers | wc -l) -ne 1 ]]; then
            exit 1
        fi
    fi

    echo "Check StorageClass..."
    if [ "${NUM_M}" -eq "3" ]; then
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} sc ocs-storagecluster-ceph-rbd --no-headers | wc -l) -ne 1 ]] ; then
            exit 1
        fi
    else
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} sc openshift-storage.noobaa.io --no-headers | wc -l) -ne 1 ]] ; then
            exit 1
        fi
    fi
done

echo ">>>>EOF"
echo ">>>>>>>"
