#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Extract the Edgecluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${edgecluster} secret/${edgecluster}-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

index=0
for edgecluster in ${ALLEDGECLUSTERS}; do
    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig ${edgecluster}
    echo ">>>> Check if edgecluster ${edgecluster} require gpu-operator."
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    if [[ $(yq eval ".edgeclusters[${index}].${edgecluster}.contrib|keys" ${EDGECLUSTERS_FILE} | grep gpu-operator | wc -l) -eq 0 ]]; then
        echo ">>>> Edgecluster ${edgecluster} does not require gpu-operator."
        exit 0
    fi

    if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get crd nodefeaturediscoveries.nfd.openshift.io | wc -l) -ne 0 && $(oc --kubeconfig=${EDGE_KUBECONFIG} get crd clusterpolicies.nvidia.com | wc -l) -ne 0 ]]; then
        echo ">>>> Edgecluster ${edgecluster} already have gpu-operator."
        exit 0
    fi
    let index++
done
exit 1
