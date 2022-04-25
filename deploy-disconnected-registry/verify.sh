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
elif [[ ${1} == 'spoke' ]]; then
    TG_KUBECONFIG=${SPOKE_KUBECONFIG}
fi
if [[ ! ${CUSTOM_REGISTRY} ]]; then
    if [[ $(oc --kubeconfig=${TG_KUBECONFIG} get ns | grep ${REGISTRY} | wc -l) -eq 0 || $(oc --kubeconfig=${TG_KUBECONFIG} get -n ztpfw-registry deployment ztpfw-registry -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
        #namespace or resources does not exist. Launching the step to create it...
        exit 1
    fi
fi
exit 0
