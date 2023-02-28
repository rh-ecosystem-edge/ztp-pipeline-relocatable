#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Verifying LVMCluster and StorageCluster: hub"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "Check Pods..."
if [[ $(oc get --kubeconfig=${KUBECONFIG_HUB} pod -n openshift-storage --no-headers | grep topolvm | grep -i running | wc -l) -eq 0 ]]; then
#odf in the edgecluster not exists so we need to create it
exit 1
fi

echo "Check StorageClass..."
if [[ $(oc get --kubeconfig=${KUBECONFIG_HUB} sc lvms-vg1 --no-headers | wc -l) -ne 1 ]]; then
exit 1
fi

echo "Check LVMCluster..."
if [[ $(oc get --kubeconfig=${KUBECONFIG_HUB} -n openshift-storage lvmcluster odf-lvmcluster --no-headers | wc -l) -ne 1 ]]; then
exit 1
fi

echo ">>>>EOF"
echo ">>>>>>>"
