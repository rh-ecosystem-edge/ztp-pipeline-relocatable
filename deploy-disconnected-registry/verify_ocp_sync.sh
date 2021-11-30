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

#TODO improve the registry with this try
#podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET} # to create a merge with the registry original adding the registry auth entry
#if [[ $(oc adm release info "${DESTINATION_REGISTRY}"/"${OCP_DESTINATION_REGISTRY_IMAGE_NS}":"${OCP_RELEASE_FULL}"-x86_64 --registry-config="${PULL_SECRET}" |wc -l) -gt 1 ]]; then  ## line 1 == error line. If found image should show more information (>1 line)
#	#Everyting is ready
#	exit 1
#else
#	#image has not been pulled and does not exist. Launching the step to create it...
#	exit 0
#fi

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
