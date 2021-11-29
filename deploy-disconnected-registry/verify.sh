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

if [[ $(oc get ns | grep ${REGISTRY} | wc -l) -eq 0 ]]; then
  #namespace does not exist. Launching the step to create it...
  exit 0
elif [[ $(oc get -n kubeframe-registry deployment kubeframe-registry -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
  #Resources are not ready...Launching the step to create them...
  exit 0
else
  #Everyting is ready
  exit 1
fi 
