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
    if ./verify.sh ; then
        echo ">>>> Deploy internal registry on: ${REGISTRY} Namespace"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        # TODO: Render variables instead being static
        oc create namespace ${REGISTRY} -o yaml --dry-run=client | oc apply -f -
        htpasswd -bBc ${AUTH_SECRET} ${REG_US} ${REG_PASS}
        oc -n ${REGISTRY} create secret generic ${SECRET} --from-file=${AUTH_SECRET} -o yaml --dry-run=client | oc apply -f -
        oc -n ${REGISTRY} create configmap registry-conf --from-file=config.yml -o yaml --dry-run=client | oc apply -f -
        oc -n ${REGISTRY} create -f ${REGISTRY_MANIFESTS}/deployment.yaml -o yaml --dry-run=client | oc apply -f -
        oc -n ${REGISTRY} create -f ${REGISTRY_MANIFESTS}/service.yaml -o yaml --dry-run=client | oc apply -f -
        oc -n ${REGISTRY} create -f ${REGISTRY_MANIFESTS}/pvc-registry.yaml -o yaml --dry-run=client | oc apply -f -
        oc -n ${REGISTRY} create -f ${REGISTRY_MANIFESTS}/route.yaml -o yaml --dry-run=client | oc apply -f -

		echo ">>>> Trusting internal registry"
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
		## Update trusted CA from Helper
		oc --kubeconfig=${KUBECONFIG_HUB} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d >/etc/pki/ca-trust/source/anchors/internal-registry.crt
		update-ca-trust extract

		../"$SHARED_DIR"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${REGISTRY}"
	else
		echo ">>>> This step to deploy registry is not neccesary, everything looks ready"
	fi
fi
