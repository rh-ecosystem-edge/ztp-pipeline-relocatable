#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh hub
if [[ $(oc adm release info "${DESTINATION_REGISTRY}"/"${OCP_DESTINATION_REGISTRY_IMAGE_NS}":"${OCP_RELEASE_FULL}"-x86_64 | wc -l ) -eq 1 ]]; then
  #image has not been pulled and does not exist. Launching the step to create it...
  exit 0
else
  #Everyting is ready
  exit 1
fi 
