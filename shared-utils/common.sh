#!/bin/bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration YAML defined in ${SPOKES_FILE}
# SPOKES_FILE variable must be exported in the environment

echo ">>>> Grabbing info from configuration yaml at ${SPOKES_FILE}"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

function grab_domain() {
    echo ">> Getting the Domain from the Hub cluster"
    export HUB_BASEDOMAIN=$(oc --kubeconfig=${KUBECONFIG_HUB} get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}' | cut -d . -f 3-)
}

function grab_hub_dns() {
    echo ">> Getting the cluster's DNS"
    export HUB_NODE_IP=$(oc --kubeconfig=${KUBECONFIG_HUB} get $(oc --kubeconfig=${KUBECONFIG_HUB} get node -o name | head -1) -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    export HUB_DNS=$($SSH_COMMAND core@${HUB_NODE_IP} "grep -v ${HUB_NODE_IP} /etc/resolv.conf | grep nameserver | cut -f2 -d\ ")
}

function grab_api_ingress() {
    # Spoke Cluster Name using the Hub's domain as a base
    cluster=${1}

    grab_domain
    grab_hub_dns
    export SPOKE_API_NAME="api.${cluster}.${HUB_BASEDOMAIN}"
    export SPOKE_API_IP="$(dig @${HUB_DNS} +short ${SPOKE_API_NAME})"
    export SPOKE_INGRESS_NAME="apps.${cluster}.${HUB_BASEDOMAIN}"
    export REGISTRY_URL="kubeframe-registry-kubeframe-registry"
    export SPOKE_INGRESS_IP="$(dig @${HUB_DNS} +short ${REGISTRY_URL}.${SPOKE_INGRESS_NAME})"
}

# SPOKES_FILE variable must be exported in the environment
if [ ! -f "${SPOKES_FILE}" ]; then
    echo "File ${SPOKES_FILE} does not exist"
    exit 1
fi

export OC_RHCOS_RELEASE=$(yq eval ".config.OC_RHCOS_RELEASE" ${SPOKES_FILE})
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${SPOKES_FILE})
export OC_OCS_VERSION=$(yq eval ".config.OC_OCS_VERSION" ${SPOKES_FILE})
export OC_OCP_TAG=$(yq eval ".config.OC_OCP_TAG" ${SPOKES_FILE})
export OC_OCP_VERSION=$(yq eval ".config.OC_OCP_VERSION" ${SPOKES_FILE})
export OC_DIS_CATALOG=kubeframe-catalog
export MARKET_NS=openshift-marketplace
export KUBEFRAME_NS=kubeframe
export OUTPUTDIR=${WORKDIR}/build
export SCP_COMMAND='scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q -r'
export SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q'

[ -d ${OUTPUTDIR} ] || mkdir -p ${OUTPUTDIR}

export KUBECONFIG_HUB=${KUBECONFIG}
export PULL_SECRET=${OUTPUTDIR}/pull-secret.json

if [[ ! -f ${PULL_SECRET} ]]; then
    echo "Pull secret file ${PULL_SECRET} does not exist, grabbing from OpenShift"
    oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d >${PULL_SECRET}
fi

export ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
