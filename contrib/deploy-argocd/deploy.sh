#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m
set -x 

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

        index=$((index + 1))
        echo ">>>> Deploy manifests to create template namespace in: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${edgecluster}"
        extract_kubeconfig ${edgecluster}
        ##############################################################################
        # Here can be added other manifests to create the required resources
        ##############################################################################

        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-namespace.yml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-subscription.yml
        sleep 2
        check_resource "crd" "gitopsservices.pipelines.openshift.io" "Established" "argocd" "${EDGE_KUBECONFIG}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-instance.yml
        sleep 2

        ##############################################################################
        # End of customization
        ##############################################################################
    done

fi

echo ">>>>EOF"
echo ">>>>>>>"
