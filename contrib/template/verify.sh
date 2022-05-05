#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${spoke} secret/${spoke}-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
    echo "Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}
    
    #############################################################################################
    ##### Here should be added the validation if the desired resources are already deployed #####
    #############################################################################################
    echo ">>>> Verifying Namespace template for: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Check Namespace..."
    if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} ns contrib-template | grep -i running | wc -l) -ne $(oc --kubeconfig=${SPOKE_KUBECONFIG} get pod -n openshift-local-storage --no-headers | grep -v Completed | wc -l) ]]; then
        # contrib-template namespace does not exists so we need to create it
        exit 1
    fi
    #############################################################################################
    ### End of validation if the desired resources are already deployed #########################
    #############################################################################################
done

echo ">>>>EOF"
echo ">>>>>>>"
