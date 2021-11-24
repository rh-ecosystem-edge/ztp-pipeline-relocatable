#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

if [[ $# -lt 1 ]]; then
	echo "Usage :"
	echo "  \$1: hub|spoke"
	echo "Sample: "
	echo "  $0 hub|spoke"
	exit 1
fi

# variables
# #########
echo ">>>> Get the pull secret from hub to file ./pull-secret.json"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
export KUBECONFIG_HUB=${KUBECONFIG}
oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d >./pull-secret.json
export PULL_SECRET=./pull-secret.json
export SOURCE_PACKAGES='kubernetes-nmstate-operator,metallb-operator,ocs-operator'
export OCP_RELEASE=${OC_OCP_VERSION}
export OCP_RELEASE_FULL=${OCP_RELEASE}.0

if [[ "${1}" == "hub" ]]; then
	echo ">>>> Get the registry cert and update pull secret for: ${1}"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	export OCP_RELEASE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.version'})
	export OPENSHIFT_RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-x86_64"
	export SOURCE_INDEX="registry.redhat.io/redhat/redhat-operator-index:v${OCP_RELEASE}"
	export DESTINATION_REGISTRY="$(oc get route -n openshift-image-registry default-route -o jsonpath={'.status.ingress[0].host'})"
	## OLM
	## NS where the OLM images will be mirrored
	export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
	## NS where the OLM INDEX for RH OPERATORS image will be mirrored
	export OLM_DESTINATION_REGISTRY_INDEX_NS=olm-index/redhat-operator-index
	## OLM INDEX IMAGE
	export OLM_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OCP_RELEASE_FULL}"
	## OCP
	## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
	export OCP_DESTINATION_REGISTRY_IMAGE_NS=ocp4/openshift4
	## OCP INDEX IMAGE
	export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OCP_RELEASE}"

elif [[ "${1}" == "spoke" ]]; then
	echo "TO BE IMPLEMENTED"
	exit 1
	#export SOURCE_INDEX="$LOCAL_REG"
	#export DESTINATION_INDEX="$(oc get route bkaaskldhaolkdsja)"
	#export DESTINATION_REGISTRY=${DESTINATION_INDEX%%/*}
	#export DESTINATION_REGISTRY_IMAGE_NS=olm
fi
