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
source ./common.sh hub

if [[ $(oc get ns | grep ${REGISTRY} | wc -l) -eq 0 || $(oc get -n kubeframe-registry deployment kubeframe-registry -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
	#namespace or resources does not exist. Launching the step to create it...
	exit 1
fi
exit 0
