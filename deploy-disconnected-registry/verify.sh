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
source ./common.sh ${1}

if [[ ${1} == 'hub' ]]; then
    TG_KUBECONFIG=${KUBECONFIG_HUB}
    DEPLOYMENT_NAME=ztpfw-registry
elif [[ ${1} == 'edgecluster' ]]; then
    TG_KUBECONFIG=${EDGE_KUBECONFIG}
    DEPLOYMENT_NAME=ztpfw-registry-quay-app
fi


if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
    if [[ $(oc --kubeconfig=${TG_KUBECONFIG} get ns | grep ${REGISTRY} | wc -l) -eq 0 || $(oc --kubeconfig=${TG_KUBECONFIG} get -n ztpfw-registry deployment $DEPLOYMENT_NAME -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
        #namespace or resources does not exist. Launching the step to create it...
        exit 1
    fi
fi 

if [[ $(oc get --kubeconfig=${TG_KUBECONFIG} route -n ${REGISTRY} --no-headers | wc -l) -lt 1 ]]; then
    exit 2
fi


exit 0
