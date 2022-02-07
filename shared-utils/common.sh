#!/usr/bin/env bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration YAML defined in ${SPOKES_FILE}
# SPOKES_FILE variable must be exported in the environment

function extract_kubeconfig_common() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    cluster=${1}

    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${cluster}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${cluster} secret/${cluster}-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

function extract_kubeadmin_pass_common() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    cluster=${1}

    export SPOKE_KUBEADMIN_PASS=${OUTPUTDIR}/${cluster}-kubeadmin-password
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${cluster} secret/${cluster}-admin-password --to - >${SPOKE_KUBEADMIN_PASS}
}

function copy_files_common() {
    src_files=${1}
    dst_node=${2}
    dst_folder=${3}

    if [[ -z ${src_files} ]]; then
        echo "Source files variable empty: ${src_files[@]}"
        exit 1
    fi

    if [[ -z ${dst_node} ]]; then
        echo "Destination IP variable empty: ${dst_node}"
        exit 1
    fi

    if [[ -z ${dst_folder} ]]; then
        echo "Destination folder variable empty: ${dst_folder}"
        exit 1
    fi

    echo "Copying source files: ${src_files[@]} to Node ${dst_node}"
    ${SCP_COMMAND} ${src_files[@]} core@${dst_node}:${dst_folder}
}

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
export KUBECONFIG_HUB=${KUBECONFIG}

echo ">>>> Grabbing info from Spokes File"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

export OC_DIS_CATALOG=kubeframe-catalog
export MARKET_NS=openshift-marketplace
export KUBEFRAME_NS=kubeframe
export OUTPUTDIR=${OUTPUTDIR:-$WORKDIR/build}
export SCP_COMMAND='scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q -r'
export SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q'

[ -d ${OUTPUTDIR} ] || mkdir -p ${OUTPUTDIR}

if [ ! -z ${SPOKES_CONFIG+x} ]; then
    if [ -z "${SPOKES_FILE+x}" ]; then
        export SPOKES_FILE="${OUTPUTDIR}/spokes.yaml"
    fi

	echo "Creating ${SPOKES_FILE} from SPOKES_CONFIG"
    echo $"${SPOKES_CONFIG}" > "${SPOKES_FILE}"
fi

if [ ! -f "${SPOKES_FILE}" ]; then
    echo "File ${SPOKES_FILE} does not exist"
    exit 1
fi

export OC_RHCOS_RELEASE=$(yq eval ".config.OC_RHCOS_RELEASE" ${SPOKES_FILE})
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${SPOKES_FILE})
export OC_OCS_VERSION=$(yq eval ".config.OC_OCS_VERSION" ${SPOKES_FILE})
export OC_OCP_TAG=$(yq eval ".config.OC_OCP_TAG" ${SPOKES_FILE})
export OC_OCP_VERSION=$(yq eval ".config.OC_OCP_VERSION" ${SPOKES_FILE})
export CLUSTERIMAGESET=$(yq eval ".config.clusterimageset" ${SPOKES_FILE})

if [ -z ${KUBECONFIG+x} ]; then
	echo "Please, provide a path for the hub's KUBECONFIG: It will be created if it doesn't exist"
    exit 1
fi

if [[ ! -f "${KUBECONFIG}" && -f "/run/secrets/kubernetes.io/serviceaccount/token" ]]; then
    if [ -z "${KUBECONFIG+x}" ]; then
        export KUBECONFIG="${OUTPUTDIR}/kubeconfig"
    fi
    echo "Kubeconfig file doesn't exist: creating one from token"
    oc config set-credentials spokes-deployer --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
elif [[ ! -f "${KUBECONFIG}" ]]; then
	echo "Kubeconfig file doesn't exist"
    exit 1
fi

export KUBECONFIG_HUB=${KUBECONFIG}
export PULL_SECRET=${OUTPUTDIR}/pull-secret.json

if [[ ! -f ${PULL_SECRET} ]]; then
    echo "Pull secret file ${PULL_SECRET} does not exist, grabbing from OpenShift"
    oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d >${PULL_SECRET}
fi

export ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
