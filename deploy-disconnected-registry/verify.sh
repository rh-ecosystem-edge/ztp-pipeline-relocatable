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
MODE=${1}
source ./common.sh ${MODE}


if [[ ${MODE} == 'hub' ]];then
    TARGET_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${MODE} == 'spoke' ]];then
    TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
fi

if [[ $(oc --kubeconfig=${TARGET_KUBECONFIG} get ns | grep ${REGISTRY} | wc -l) -eq 0 || $(oc --kubeconfig=${TARGET_KUBECONFIG} get -n kubeframe-registry deployment kubeframe-registry -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
	#namespace or resources does not exist. Launching the step to create it...
	exit 1
fi
exit 0
