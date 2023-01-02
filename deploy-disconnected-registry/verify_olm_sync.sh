#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh ${1}

if [[ ${1} == 'hub' ]]; then
    TGT_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${1} == 'edgecluster' ]]; then
    TGT_KUBECONFIG=${EDGE_KUBECONFIG}
fi

echo ">>>> Verifying OLM Sync: ${1}"
registry_login ${DESTINATION_REGISTRY}

# Always trigger the mirror, let's let oc-mirror
# decide whether images need to be refreshed or not.
# TODO(flaper87): Add check to verify whether the registry
# needs to be installed or not.
exit 1
