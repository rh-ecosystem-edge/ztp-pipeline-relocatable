#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $spoke secret/$spoke-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
    echo ">>>> Verifying the MetalLb ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    deployment=$(oc --kubeconfig=${KUBECONFIG_HUB} get deployment -n metallb controller -ojsonpath={.status.availableReplicas})
    service=$(oc --kubeconfig=${KUBECONFIG_HUB} get svc -n metallb --no-headers | wc -l)
    address_pool=$(oc --kubeconfig=${KUBECONFIG_HUB} get addresspool -n metallb --no-headers | wc -l)

    if [[ ${deployment} == "1" && ${service} == "4" && ${address_pool} == "1"  ]]; then
        echo "MetalLb deployment is up and running"
    else
        echo "MetalLb deployment is not running"
        exit 1
    fi

    echo "Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}

    echo ">> Checking external access to the spoke ${spoke}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} get nodes --no-headers
    if [[ ${?} != 0 ]]; then
        echo "ERROR: You cannot access ${spoke} spoke cluster externally"
        exit 1
    fi

    echo ">> external access with spoke ${spoke} Verified"
    echo
done

echo ">>>>EOF"
echo ">>>>>>>"
