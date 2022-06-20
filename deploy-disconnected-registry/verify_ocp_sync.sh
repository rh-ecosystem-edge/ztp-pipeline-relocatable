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
# debug options
debug_status starting

if [[ ${1} == 'hub' ]]; then
    TARGET_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${1} == 'edgecluster' ]]; then
    TARGET_KUBECONFIG=${EDGE_KUBECONFIG}
fi

registry_login ${DESTINATION_REGISTRY}
if [[ $(oc --kubeconfig=${TARGET_KUBECONFIG} adm release info "${DESTINATION_REGISTRY}"/"${OCP_DESTINATION_REGISTRY_IMAGE_NS}":"${OC_OCP_TAG}" --registry-config="${PULL_SECRET}" | wc -l) -gt 1 ]]; then ## line 1 == error line. If found image should show more information (>1 line)
    #Everyting is ready
    echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"
    debug_status ended
    exit 0
fi
#image has not been pulled and does not exist. Launching the step to create it...
exit 1
