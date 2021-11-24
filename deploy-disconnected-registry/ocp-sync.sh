#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
source ./common.sh ${1}

if [ $(oc get ns | grep ocp4 | wc -l) -eq 0 ]; then
	oc create ns ocp4
fi

export REGISTRY_NAME="$(oc get route -n openshift-image-registry default-route -o jsonpath={'.status.ingress[0].host'})"
oc -n ocp4 create sa robot
oc -n ocp4 adm policy add-role-to-user registry-editor -z robot
podman login ${DESTINATION_REGISTRY} -u robot -p $(oc -n ocp4 serviceaccounts get-token robot) --authfile=${PULL_SECRET}

echo ">>>> Mirror Openshift Version"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc adm release mirror -a ${PULL_SECRET} --from="${OPENSHIFT_RELEASE_IMAGE}" --to-release-image="${OCP_DESTINATION_INDEX}" --to="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}"
