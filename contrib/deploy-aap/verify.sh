#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

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

for edgecluster in ${ALLEDGECLUSTERS}; do
    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig ${edgecluster}

    #############################################################################################
    ##### Here should be added the validation if the desired resources are already deployed #####
    #############################################################################################
    echo ">>>> Verifying Namespace template for: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Check Namespace..."
    if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} ns contrib-template | grep -i running | wc -l) -ne $(oc --kubeconfig=${EDGE_KUBECONFIG} get pod -n openshift-local-storage --no-headers | grep -v Completed | wc -l) ]]; then
        # contrib-template namespace does not exists so we need to create it
        exit 1
    fi
    #############################################################################################
    ### End of validation if the desired resources are already deployed #########################
    #############################################################################################
done

echo ">>>>EOF"
echo ">>>>>>>"
