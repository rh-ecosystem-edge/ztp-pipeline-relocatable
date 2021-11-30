#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh

source ./common.sh ${1}

if [[ "$1" == 'hub' ]]; then
    if ./verify_ocp_sync.sh ; then
		oc create namespace ${REGISTRY} -o yaml --dry-run=client | oc apply -f -

		export REGISTRY_NAME="$(oc get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
		podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET} # to create a merge with the registry original adding the registry auth entry

		echo ">>>> Mirror Openshift Version"
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
		oc adm release mirror -a ${PULL_SECRET} --from="${OPENSHIFT_RELEASE_IMAGE}" --to-release-image="${OCP_DESTINATION_INDEX}" --to="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}"
	else
		echo ">>>> This step to mirror ocp is not neccesary, everything looks ready"
	fi
fi
