#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $spoke secret/$spoke-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ! ./verify.sh; then

    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    index=0
    for spoke in ${ALLSPOKES}; do

        index=$((index + 1))
        echo ">>>> Deploy manifests to create template namespace in: ${spoke}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${spoke}"
        extract_kubeconfig ${spoke}
        ##############################################################################
        ##### Here can be added other manifests to create the required resources #####
        ##############################################################################
        
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-template-namespace.yaml
        
    done

fi

echo ">>>>EOF"
echo ">>>>>>>"
