#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# debug options
debug_status starting

function create_cs() {

    local mode=${1}

    if [[ ${mode} == 'hub' ]]; then
        local CS_OUTFILE=${OUTPUTDIR}/catalogsource-hub.yaml
        local cluster="hub"
    elif [[ ${mode} == 'edgecluster' ]]; then
        local cluster=${2}
        local CS_OUTFILE=${OUTPUTDIR}/catalogsource-${cluster}.yaml
    fi

    cat >${CS_OUTFILE} <<EOF

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${OC_DIS_CATALOG}
  namespace: ${MARKET_NS}
spec:
  sourceType: grpc
  image: ${OLM_DESTINATION_INDEX}
  displayName: Disconnected Lab
  publisher: disconnected-lab
  updateStrategy:
    registryPoll:
      interval: 30m
EOF
    echo

    if [ -z $CERTIFIED_SOURCE_PACKAGES ]; then
        echo ">>>> There are no certified operators to be mirrored"
    else
        cat >>${CS_OUTFILE} <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${OC_DIS_CATALOG}-certfied
  namespace: ${MARKET_NS}
spec:
  sourceType: grpc
  image: ${OLM_CERTIFIED_DESTINATION_INDEX}
  displayName: Disconnected Lab Certified
  publisher: disconnected-lab-certified
  updateStrategy:
    registryPoll:
      interval: 30m
EOF
    fi
    echo
}

function trust_internal_registry() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  trust_internal_registry hub|edgecluster <edgecluster name>"
        exit 1
    fi

    if [[ ${1} == 'hub' ]]; then
        KBKNFG=${KUBECONFIG_HUB}
        clus="hub"
        MYREGISTRY=$(oc --kubeconfig=${KBKNFG} get route -n ztpfw-registry ztpfw-registry -o jsonpath='{.spec.host}')
    elif [[ ${1} == 'edgecluster' ]]; then
        KBKNFG=${EDGE_KUBECONFIG}
        clus=${2}
        MYREGISTRY=$(oc --kubeconfig=${KBKNFG} get route -n ztpfw-registry ztpfw-registry-quay -o jsonpath='{.spec.host}')
    fi

    export PATH_CA_CERT="/etc/pki/ca-trust/source/anchors/internal-registry-${clus}.crt"
    echo ">>>> Trusting internal registry: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo ">> Kubeconfig: ${KBKNFG}"
    echo ">> Mode: ${1}"
    echo ">> Cluster: ${clus}"

    if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
        ## Update trusted CA from Helper
        #TODO after sync pull secret global because crictl can't use flags and uses the generic with https://access.redhat.com/solutions/4902871
        export CA_CERT_DATA=$(oc --kubeconfig=${KBKNFG} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}')
        echo ">> Cert: ${PATH_CA_CERT}"
    else
        export CA_CERT_DATA=$(openssl s_client -connect ${LOCAL_REG} -showcerts </dev/null  | openssl x509 | base64 |  tr -d '\n' )
        MYREGISTRY=${LOCAL_REG}
    fi

    ## Update trusted CA from Helper
    echo "${CA_CERT_DATA}" | base64 -d >"${PATH_CA_CERT}"
    echo "${CA_CERT_DATA}" | base64 -d >"${WORKDIR}/build/internal-registry-${clus}.crt"
    update-ca-trust extract
    echo ">> Done!"
    echo

    # Add certificate to OpenShift configuration

    oc --kubeconfig=${KBKNFG} create configmap ztpfwregistry -n openshift-config --from-file=${MYREGISTRY}=${PATH_CA_CERT}
    oc --kubeconfig=${KBKNFG} patch image.config.openshift.io/cluster --patch '{"spec":{"additionalTrustedCA":{"name":"ztpfwregistry"}}}' --type=merge

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

export SOURCE_PACKAGES='quay-operator,kubernetes-nmstate-operator,metallb-operator,ocs-operator,local-storage-operator,advanced-cluster-management,mcg-operator,nfd'
export CERTIFIED_SOURCE_PACKAGES='gpu-operator-certified'
export PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
export CERTIFIED_PACKAGES_FORMATED=$(echo ${CERTIFIED_SOURCE_PACKAGES} | tr "," " ")
export EXTRA_IMAGES=('quay.io/jparrill/registry:3' 'registry.access.redhat.com/rhscl/httpd-24-rhel7:latest' 'quay.io/ztpfw/ui:latest')
# TODO: Change static passwords by dynamic ones
export REG_US=dummy
export REG_PASS=dummy123

if [[ ${1} == "hub" ]]; then
    echo ">>>> Get the registry cert and update pull secret for: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    export OPENSHIFT_RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${OC_OCP_TAG}"
    export SOURCE_REGISTRY="quay.io"
    export SOURCE_INDEX="registry.redhat.io/redhat/redhat-operator-index:v${OC_OCP_VERSION_MIN}"
    export CERTIFIED_SOURCE_INDEX="registry.redhat.io/redhat/certified-operator-index:v${OC_OCP_VERSION_MIN}"
    if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
        export DESTINATION_REGISTRY="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
    else
        export DESTINATION_REGISTRY=${LOCAL_REG}
    fi
    # OLM
    ## NS where the OLM images will be mirrored
    export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
    ## Image name where the OLM INDEX for RH OPERATORS image will be mirrored
    export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat-operator-index
    ## OLM INDEX IMAGE
    export OLM_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"

    ## NS where the OLM CERTIFIED images will be mirrored
    export OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS=olm
    ## Image name where the OLM INDEX for RH CERTIFIED OPERATORS image will be mirrored
    export OLM_CERTIFIED_DESTINATION_REGISTRY_INDEX_NS=${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}/certified-operator-index
    ## OLM CERTIFIED INDEX IMAGE
    export OLM_CERTIFIED_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"
    # OCP
    ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
    export OCP_DESTINATION_REGISTRY_IMAGE_NS=ocp4/openshift4
    ## OCP INDEX IMAGE
    export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"

elif [[ ${1} == "edgecluster" ]]; then
    if [[ ${EDGE_KUBECONFIG:-} == "" ]]; then
        echo "Avoiding Hub <-> Edge-cluster sync on favor of registry deployment"
    else
        echo ">>>> Filling variables for Registry sync on Edge-cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "HUB: ${KUBECONFIG_HUB}"
        echo "EDGE: ${EDGE_KUBECONFIG}"
        ## Common
        export DESTINATION_REGISTRY="$(oc --kubeconfig=${EDGE_KUBECONFIG} get route -n ${REGISTRY} ${REGISTRY}-quay -o jsonpath={'.status.ingress[0].host'})"
        ## OCP Sync vars
        export OPENSHIFT_RELEASE_IMAGE="$(oc --kubeconfig=${KUBECONFIG_HUB} get clusterimageset --no-headers openshift-v${OC_OCP_VERSION_FULL} -o jsonpath={.spec.releaseImage})"
        ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
        export OCP_DESTINATION_REGISTRY_IMAGE_NS=ocp4/openshift4
        ## OCP INDEX IMAGE
        export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"

        ## OLM Sync vars
        export SOURCE_REGISTRY="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
        ## NS where the OLM images will be mirrored
        export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
        ## Image name where the OLM INDEX for RH OPERATORS image will be mirrored
        export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat-operator-index

        export SOURCE_INDEX="${SOURCE_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"
        export OLM_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"

        ## NS where the OLM CERTIFIED images will be mirrored
        export OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS=olm
        ## Image name where the OLM INDEX for RH OPERATORS image will be mirrored
        export OLM_CERTIFIED_DESTINATION_REGISTRY_INDEX_NS=${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}/certified-operator-index

        export CERTIFIED_SOURCE_INDEX="${SOURCE_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"
        export OLM_CERTIFIED_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION_MIN}"
    fi
fi

# debug options
debug_status ended
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"