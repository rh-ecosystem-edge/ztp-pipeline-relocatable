#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function trust_internal_registry() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  trust_internal_registry hub|edgecluster <edgecluster name>"
        exit 1
    fi

    if [[ ${1} == 'hub' ]]; then
        KBKNFG=${KUBECONFIG_HUB}
        clus="hub"
		    MYREGISTRY="$(oc --kubeconfig=${KBKNFG} get configmap  --namespace ${REGISTRY} ztpfw-config -o jsonpath='{.data.uri}' | base64 -d)"
		    if [[ ${CUSTOM_REGISTRY} != "true" ]]; then
		      CUSTOM_REGISTRY_URL=${MYREGISTRY}
		    fi
		    REGISTRY_NAME=$( echo  ${CUSTOM_REGISTRY_URL} | cut -d":" -f1 )
	  elif [[ ${1} == 'edgecluster' ]]; then
        KBKNFG=${EDGE_KUBECONFIG}
        clus=${2}
        MYREGISTRY=$(oc --kubeconfig=${KBKNFG} get route -n ztpfw-registry ztpfw-registry-quay -o jsonpath='{.spec.host}')
		    REGISTRY_NAME="${MYREGISTRY}"
    fi

    export PATH_CA_CERT="/etc/pki/ca-trust/source/anchors/internal-registry-${clus}.crt"
    echo ">>>> Trusting internal registry: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo ">> Kubeconfig: ${KBKNFG}"
    echo ">> Mode: ${1}"
    echo ">> Cluster: ${clus}"


    ## Update trusted CA from Helper
    #TODO after sync pull secret global because crictl can't use flags and uses the generic with https://access.redhat.com/solutions/4902871
    if [[ ${CUSTOM_REGISTRY} == "true" ]] && [[ "${1}" == "hub"  ]]; then
        export CA_CERT_DATA=$(openssl s_client -connect ${CUSTOM_REGISTRY_URL} -showcerts < /dev/null | openssl x509 | base64 | tr -d '\n')
    else
		export CA_CERT_DATA=$(oc --kubeconfig=${KBKNFG} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}')

    fi
    echo ">> Cert: ${PATH_CA_CERT}"

    ## Update trusted CA from Helper
    echo "${CA_CERT_DATA}" | base64 -d >"${PATH_CA_CERT}"
    echo "${CA_CERT_DATA}" | base64 -d >"${WORKDIR}/build/internal-registry-${clus}.crt"
    update-ca-trust extract
    echo ">> Done!"
    echo

    # Add certificate to OpenShift configuration
    oc --kubeconfig=${KBKNFG} create configmap ztpfwregistry -n openshift-config --from-file=${REGISTRY_NAME}=${PATH_CA_CERT}
    oc --kubeconfig=${KBKNFG} patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"ztpfwregistry"}}}' --type=merge

}

function get_external_registry_cert() {
    KBKNFG=${EDGE_KUBECONFIG}
    echo "INFO: Getting external registry cert"
    export CA_CERT_DATA=$(openssl s_client -connect ${CUSTOM_REGISTRY_URL} -showcerts < /dev/null | openssl x509 | base64 | tr -d '\n')

    export PATH_CA_CERT="/etc/pki/ca-trust/source/anchors/external-registry-edge.crt"
    echo "${CA_CERT_DATA}" | base64 -d >"${PATH_CA_CERT}"
    echo "${CA_CERT_DATA}" | base64 -d >"${WORKDIR}/build/external-registry-edge.crt"

    update-ca-trust extract

    echo "INFO: updating openthift config with new certifecate"

    MYREGISTRY=$( echo  ${CUSTOM_REGISTRY_URL} | cut -d":" -f1 )
    oc --kubeconfig=${KBKNFG} create configmap ztpfwregistry-external -n openshift-config --from-file=${MYREGISTRY}=${PATH_CA_CERT}
    oc --kubeconfig=${KBKNFG} patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"ztpfwregistry-external"}}}' --type=merge

}
if [[ $# -lt 1 ]]; then
    echo "Usage :"
    echo '  $1: hub|edgecluster'
    echo "Sample: "
    echo "  ${0} hub|edgecluster"
    exit 1
fi

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Get the pull secret from hub to file pull-secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
export AUTH_SECRET=../${SHARED_DIR}/htpasswd
export REGISTRY_MANIFESTS=manifests
export QUAY_MANIFESTS=quay-manifests
export SECRET=auth
export REGISTRY_CONFIG=config.yml

export EXTRA_IMAGES=('quay.io/jparrill/registry:3' 'registry.access.redhat.com/rhscl/httpd-24-rhel7:latest' 'quay.io/ztpfw/ui:latest')

# TODO: Change static passwords by dynamic ones
export REG_US=dummy
export REG_PASS=dummy123

if [[ ${1} == "hub" ]]; then
    echo ">>>> Get the registry cert and update pull secret for: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    export OPENSHIFT_RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${OC_OCP_TAG}"
    export SOURCE_REGISTRY="quay.io"
    export REDHAT_OPERATORS_INDEX="registry.redhat.io/redhat/redhat-operator-index"
    export CERTIFIED_OPERATORS_INDEX="registry.redhat.io/redhat/certified-operator-index"

    export DESTINATION_REGISTRY="$(oc get configmap  --namespace ${REGISTRY} ztpfw-config -o jsonpath='{.data.uri}' | base64 -d)"
    # OLM
    ## NS where the OLM images will be mirrored
    export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
    ## Image name where the OLM INDEX for RH OPERATORS image will be mirrored
    #export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat/redhat-operator-index
    export OLM_DESTINATION_REGISTRY_INDEX_NS=ztpfw/redhat/redhat-operator-index

    # OCP
    ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
    export OCP_DESTINATION_REGISTRY_IMAGE_NS=ztpfw/openshift/release-images
    ## OCP INDEX IMAGE
    export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"
    export OC_MIRROR_DESTINATION_REGISTRY=${DESTINATION_REGISTRY}

elif [[ ${1} == "edgecluster" ]]; then
    if [[ ${EDGE_KUBECONFIG:-} == "" ]]; then
        echo "Avoiding Hub <-> Edge-cluster sync on favor of registry deployment"
    else
        echo ">>>> Filling variables for Registry sync on Edge-cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "HUB: ${KUBECONFIG_HUB}"
        echo "EDGE: ${EDGE_KUBECONFIG}"
        echo "REGISTRY NS: ${REGISTRY}"

        if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get ns | grep ${REGISTRY} | wc -l) -gt 0 && $(oc --kubeconfig=${EDGE_KUBECONFIG} get -n ztpfw-registry deployment ztpfw-registry-quay-app  -ojsonpath='{.status.availableReplicas}') -gt 0 ]]; then
          echo "Registry NS exists so, we can continue with the workflow"
          ## Common
          ## FIX the race condition where the MCO is restarting services and get lost the route query
          echo ">>>> Check route to ensure is available"
          echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
          timeout=0
          ready=false
          echo "DEBUG: oc --kubeconfig=${EDGE_KUBECONFIG} get route -n ${REGISTRY} ${REGISTRY}-quay -o jsonpath={'.status.ingress[0].host'}"
          while [ "$timeout" -lt "150" ]; do
              if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} route  -n ${REGISTRY} ${REGISTRY}-quay 2> /dev/null) ]]; then
              ready=true
              break
              fi
              sleep 5
              echo "Waiting to get the registry route available"
              timeout=$((timeout + 1))
          done

          if [ "$ready" == "false" ]; then
              echo "timeout waiting for route after mco service restart..."
              exit 1
          fi
          export DESTINATION_REGISTRY="$(oc --kubeconfig=${EDGE_KUBECONFIG} get route -n ${REGISTRY} ${REGISTRY}-quay -o jsonpath={'.status.ingress[0].host'})"
          ## OCP Sync vars
          echo "DESTINATION_REGISTRY: ${DESTINATION_REGISTRY}"

          export OPENSHIFT_RELEASE_IMAGE="$(oc --kubeconfig=${KUBECONFIG_HUB} get clusterimageset --no-headers openshift-v${OC_OCP_VERSION_FULL} -o jsonpath={.spec.releaseImage})"
          ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
          export OCP_DESTINATION_REGISTRY_IMAGE_NS=ztpfw/openshift/release-image
          ## OCP INDEX IMAGE
          export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"

          ## OLM Sync vars
          export SOURCE_REGISTRY="$(oc --kubeconfig=${KUBECONFIG_HUB} get configmap  --namespace ${REGISTRY} ztpfw-config -o jsonpath='{.data.uri}' | base64 -d)"

          ## NS where the OLM images will be mirrored
          export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
          ## Image name where the OLM INDEX for RH OPERATORS image will be mirrored
          #export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat/redhat-operator-index
          export OLM_DESTINATION_REGISTRY_INDEX_NS=ztpfw/redhat/redhat-operator-index

          export OC_MIRROR_DESTINATION_REGISTRY=${DESTINATION_REGISTRY}/ztpfw
	  export REDHAT_OPERATORS_INDEX=$(oc --kubeconfig=${KUBECONFIG_HUB} get catalogsource -n openshift-marketplace redhat-operators -o template={{.spec.image}})
	  export REDHAT_OPERATORS_INDEX="${REDHAT_OPERATORS_INDEX%%:*}"
	  export CERTIFIED_OPERATORS_INDEX=$(oc --kubeconfig=${KUBECONFIG_HUB} get catalogsource -n openshift-marketplace certified-operators -o template={{.spec.image}})
	  export CERTIFIED_OPERATORS_INDEX="${CERTIFIED_OPERATORS_INDEX%%:*}"
        fi
    fi
fi
