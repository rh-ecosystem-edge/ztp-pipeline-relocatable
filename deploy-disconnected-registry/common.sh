#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function create_cs() {

    local mode=${1}

    if [[ ${mode} == 'hub' ]]; then
        local CS_OUTFILE=${OUTPUTDIR}/catalogsource-hub.yaml
        local cluster="hub"
    elif [[ ${mode} == 'spoke' ]]; then
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
}

function trust_internal_registry() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  trust_internal_registry hub|spoke <spoke name>"
        exit 1
    fi

    if [[ ${1} == 'hub' ]]; then
        KBKNFG=${KUBECONFIG_HUB}
        clus="hub"
    elif [[ ${1} == 'spoke' ]]; then
        KBKNFG=${SPOKE_KUBECONFIG}
        clus=${2}
    fi

    echo ">>>> Trusting internal registry: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo ">> Kubeconfig: ${KBKNFG}"
    echo ">> Mode: ${1}"
    echo ">> Cluster: ${clus}"
    ## Update trusted CA from Helper
    #TODO despues el sync pull secret global porque crictl no puede usar flags y usa el generico with https://access.redhat.com/solutions/4902871
    export CA_CERT_DATA=$(oc --kubeconfig=${KBKNFG} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}')
    export PATH_CA_CERT="/etc/pki/ca-trust/source/anchors/internal-registry-${clus}.crt"
    echo ">> Cert: ${PATH_CA_CERT}"

    ## Update trusted CA from Helper
    echo "${CA_CERT_DATA}" | base64 -d >"${PATH_CA_CERT}"
    echo "${CA_CERT_DATA}" | base64 -d >"${WORKDIR}/build/internal-registry-${clus}.crt"
    update-ca-trust extract
    echo ">> Done!"
    echo
}

if [[ $# -lt 1 ]]; then
    echo "Usage :"
    echo '  $1: hub|spoke'
    echo "Sample: "
    echo "  ${0} hub|spoke"
    exit 1
fi

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Get the pull secret from hub to file pull-secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
export REGISTRY=ztpfw-registry
export AUTH_SECRET=../${SHARED_DIR}/htpasswd
export REGISTRY_MANIFESTS=manifests
export QUAY_MANIFESTS=quay-manifests
export SECRET=auth
export REGISTRY_CONFIG=config.yml

export SOURCE_PACKAGES='quay-operator,kubernetes-nmstate-operator,metallb-operator,ocs-operator,local-storage-operator,advanced-cluster-management'
export PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
export EXTRA_IMAGES=('quay.io/jparrill/registry:3' 'registry.access.redhat.com/rhscl/httpd-24-rhel7:latest' 'quay.io/ztpfw/ui:latest')
export OCP_RELEASE=${OC_OCP_VERSION}
export OCP_RELEASE_FULL=$( echo ${OCP_RELEASE} |  cut -d"-" -f 1)
# TODO: Change static passwords by dynamic ones
export REG_US=dummy
export REG_PASS=dummy123

if [[ ${1} == "hub" ]]; then
    echo ">>>> Get the registry cert and update pull secret for: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    #export OCP_RELEASE=$(oc --kubeconfig=${KUBECONFIG_HUB} get clusterversion -o jsonpath={'.items[0].status.desired.version'})
    export OPENSHIFT_RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${OCP_RELEASE}-x86_64"
    export SOURCE_REGISTRY="quay.io"
    export SOURCE_INDEX="registry.redhat.io/redhat/redhat-operator-index:v${OC_OCP_VERSION}"
    export DESTINATION_REGISTRY="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
    ## OLM
    ## NS where the OLM images will be mirrored
    export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
    ## NS where the OLM INDEX for RH OPERATORS image will be mirrored
    export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat-operator-index
    ## OLM INDEX IMAGE
    export OLM_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION}"
    ## OCP
    ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
    export OCP_DESTINATION_REGISTRY_IMAGE_NS=ocp4
    ## OCP INDEX IMAGE
    export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"

elif [[ ${1} == "spoke" ]]; then
    if [[ ${SPOKE_KUBECONFIG:-} == "" ]]; then
        echo "Avoiding Hub <-> Spoke sync on favor of registry deployment"
    else
        echo ">>>> Filling variables for Registry sync on Spoke"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "HUB: ${KUBECONFIG_HUB}"
        echo "SPOKE: ${SPOKE_KUBECONFIG}"
        ## Common
        export DESTINATION_REGISTRY="$(oc --kubeconfig=${SPOKE_KUBECONFIG} get route -n ${REGISTRY} ${REGISTRY}-quay -o jsonpath={'.status.ingress[0].host'})"
        ## OCP Sync vars
        export OPENSHIFT_RELEASE_IMAGE="$(oc --kubeconfig=${KUBECONFIG_HUB} get clusterimageset --no-headers $(yq eval ".config.clusterimageset" ${SPOKES_FILE}) -o jsonpath={.spec.releaseImage})"
        ## The NS for INDEX and IMAGE will be the same here, this is why there is only 1
        export OCP_DESTINATION_REGISTRY_IMAGE_NS=ocp4
        ## OCP INDEX IMAGE
        export OCP_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}:${OC_OCP_TAG}"

        ## OLM Sync vars
        export SOURCE_REGISTRY="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
        ## NS where the OLM images will be mirrored
        export OLM_DESTINATION_REGISTRY_IMAGE_NS=olm
        ## NS where the OLM INDEX for RH OPERATORS image will be mirrored
        export OLM_DESTINATION_REGISTRY_INDEX_NS=${OLM_DESTINATION_REGISTRY_IMAGE_NS}/redhat-operator-index

        export SOURCE_INDEX="${SOURCE_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION}"
        export OLM_DESTINATION_INDEX="${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_INDEX_NS}:v${OC_OCP_VERSION}"
    fi
fi
