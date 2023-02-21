#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

for edgecluster in ${ALLEDGECLUSTERS}; do
    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig_common ${edgecluster}
    echo ">>>> Verifying LVMCluster and StorageCluster: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Check Pods..."
    if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} pod -n openshift-storage --no-headers | grep topolvm | grep -i running | wc -l) -eq 0 ]]; then
        #odf in the edgecluster not exists so we need to create it
        exit 1
    fi

    echo "Check StorageClass..."
    if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} sc lvms-vg1 --no-headers | wc -l) -ne 1 ]]; then
        exit 1
    fi

    echo "Check LVMCluster..."
    if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} -n openshift-storage lvmcluster odf-lvmcluster --no-headers | wc -l) -ne 1 ]]; then
        exit 1
    fi
done

echo ">>>>EOF"
echo ">>>>>>>"
