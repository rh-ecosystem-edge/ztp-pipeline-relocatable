#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

debug_status starting

function extract_kubeconfig() {
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $edgecluster secret/$edgecluster-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

for edgecluster in ${ALLEDGECLUSTERS}; do

    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig ${edgecluster}

    echo ">> Checking external access to the edgecluster ${edgecluster}"
    oc --kubeconfig=${EDGE_KUBECONFIG} get nodes --no-headers
    if [[ ${?} != 0 ]]; then
        echo "ERROR: You cannot access ${edgecluster} edgecluster cluster externally"
        exit 1
    fi
    echo ">> external access with edgecluster ${edgecluster} Verified"
    echo

    echo ">>>> Verifying the MetalLb ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    deployment=$(oc --kubeconfig=${EDGE_KUBECONFIG} get deployment -n metallb controller -ojsonpath={.status.availableReplicas})
    service=$(oc --kubeconfig=${EDGE_KUBECONFIG} get svc -n metallb --no-headers | wc -l)
    address_pool=$(oc --kubeconfig=${EDGE_KUBECONFIG} get addresspool -n metallb --no-headers | wc -l)

    if [[ ${deployment} == "1" && ${service} == "4" && ${address_pool} == "1" ]]; then
        echo "MetalLb deployment is up and running"
    else
        echo "MetalLb deployment is not running"
        exit 1
    fi

done

debug_status ending 
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"
