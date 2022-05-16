#!/usr/bin/env bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration YAML defined in ${SPOKES_FILE}
# SPOKES_FILE variable must be exported in the environment

#set -x

function check_resource() {
    # 1 - Resource type: "deployment"
    # 2 - Resource name: "openshift-pipelines-operator"
    # 3 - Type Status: "Available"
    # 4 - Namespace: "openshift-operators"
    # 5 - Kubeconfig: ""

    if [[ -z ${1} ]]; then
        echo "I need a resource to check, value passed: \"${1}\""
        exit 1
    fi

    if [[ -z ${2} ]]; then
        echo "I need a resource name to check, value passed: \"${2}\""
        exit 1
    fi

    if [[ -z ${3} ]]; then
        echo "I need a Type Status (E.G 'Available') from status.conditions json field to check, value passed: \"${3}\""
        exit 1
    fi

    if [[ -z ${4} ]]; then
        echo "I need a Namespace to check the resource into, value passed: \"${4}\""
        exit 1
    fi

    if [[ -z ${5} ]]; then
        echo "I need a Kubeconfig, value passed: \"${5}\""
        exit 1
    fi

    RESOURCE="${1}"
    RESOURCE_NAME="${2}"
    TYPE_STATUS="${3}"
    NAMESPACE="${4}"
    KUBE="${5}"

    echo ">>>> Checking Resource: ${RESOURCE} with name ${RESOURCE_NAME}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        if [[ $(oc --kubeconfig=${KUBE} -n ${NAMESPACE} get ${RESOURCE} ${RESOURCE_NAME} -o jsonpath="{.status.conditions[?(@.type==\"${TYPE_STATUS}\")].status}") == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for ${RESOURCE} ${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        sleep 20
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for ${RESOURCE}-${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        exit 1
    fi
}

function trust_node_certificates() {
    # This function will copy manually the registry certificates into the OCP nodes and
    # it will replace the MCO because it takes 45 Minutes in reboot.
    # Initially no collateral effects on MCO.
    # This is only affecting the spokes, because we cannot ensure the Hub's RSA Keyfile location

    cluster=${1}
    i=${2}
    cp -f ${PATH_CA_CERT} ${SPOKE_SAFE_FOLDER}

    echo ">>>> Copying Registry Certificates to cluster: ${cluster}"
    for agent in $(oc get agents --kubeconfig=${KUBECONFIG_HUB} -n ${cluster} -o jsonpath='{.items[?(@.status.role=="master")].metadata.name}'); do
        echo
        SPOKE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${cluster} ${agent} -o jsonpath={.spec.hostname})
        master=${SPOKE_NODE_NAME##*-}
        MAC_EXT_DHCP=$(yq e ".spokes[${i}].${cluster}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
        SPOKE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent ${agent} -n ${cluster} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
        NODE_IP=${SPOKE_NODE_IP_RAW%%/*}
        if [[ -n ${NODE_IP} ]]; then
            echo "Master Node: ${master}"
            echo "AGENT: ${agent}"
            echo "IP: ${NODE_IP%%/*}"
            echo ">>>>>>>>>"
            copy_files_common "${PATH_CA_CERT}" "${NODE_IP%%/*}" "./spoke-reg-cert.crt"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "sudo mv ~/spoke-reg-cert.crt /etc/pki/ca-trust/source/anchors/"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "sudo update-ca-trust"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "sudo systemctl restart crio kubelet"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "test -f ~/.kube/config && oc delete pod -n openshift-marketplace --all"
            sleep 50
        fi
    done
}

function recover_spoke_rsa() {

    if [[ ${#} -lt 1 ]]; then
        echo "Error accessing RSA key pair, Give me the Spoke Name"
        exit 1
    fi

    spoke=${1}
    if [[ -z ${WORKDIR} ]]; then
        WORKDIR=${OUTPUTDIR}/..
    fi
    export SPOKE_SAFE_FOLDER="${WORKDIR}/${spoke}"
    export RSA_KEY_FILE="${SPOKE_SAFE_FOLDER}/${spoke}-rsa.key"
    export RSA_PUB_FILE="${SPOKE_SAFE_FOLDER}/${spoke}-rsa.key.pub"

    if [[ ! -f ${RSA_KEY_FILE} ]]; then
        echo "RSA Key for Spoke Cluster ${spoke} Not Found"
        exit 1
    else
        echo "RSA Key-pair recovered!"
    fi

}

function generate_rsa_spoke() {

    if [[ ${#} -lt 1 ]]; then
        echo "Error generating RSA key pair, Give me the Spoke Name"
        exit 1
    fi

    spoke=${1}

    if [[ -z ${WORKDIR} ]]; then
        WORKDIR=${OUTPUTDIR}/..
    fi

    export SPOKE_SAFE_FOLDER="${WORKDIR}/${spoke}"
    mkdir -p ${SPOKE_SAFE_FOLDER}
    export RSA_KEY_FILE="${SPOKE_SAFE_FOLDER}/${spoke}-rsa.key"
    export RSA_PUB_FILE="${SPOKE_SAFE_FOLDER}/${spoke}-rsa.key.pub"

    if [[ ! -f ${RSA_KEY_FILE} ]]; then
        echo "RSA Key for Spoke Cluster ${spoke} Not Found, creating one in ${SPOKE_SAFE_FOLDER} folder"
        ssh-keygen -b 4096 -t rsa -f ${RSA_KEY_FILE} -q -N ""
        echo "Checking RSA Keys generated..."
        if [[ ! -f ${RSA_KEY_FILE} || ! -f ${RSA_PUB_FILE} ]]; then
            echo "RSA Private or Public key not found"
            exit 1
        else
            echo "RSA Key-pair Found!"
        fi
    else
        echo "RSA Key for Spoke Cluster ${spoke} Found, check this folder: ${SPOKE_SAFE_FOLDER}"
    fi

}

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

    if [[ -z ${RSA_KEY_FILE} ]]; then
        echo "RSA Key not defined: ${RSA_KEY_FILE}"
        exit 1
    fi

    echo "Copying source files: ${src_files[@]} to Node ${dst_node}"
    ${SCP_COMMAND} -i ${RSA_KEY_FILE} ${src_files[@]} core@${dst_node}:${dst_folder}
}

function grab_domain() {
    echo ">> Getting the Domain from the Hub cluster"
    export HUB_BASEDOMAIN=$(oc --kubeconfig=${KUBECONFIG_HUB} get ingresscontroller -n openshift-ingress-operator default -o jsonpath='{.status.domain}' | cut -d . -f 3-)
}

function grab_hub_dns() {
    echo ">> Getting the cluster's DNS"
    export HUB_NODE_IP=$(oc --kubeconfig=${KUBECONFIG_HUB} get $(oc --kubeconfig=${KUBECONFIG_HUB} get node -o name | head -1) -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
    #export HUB_DNS=$($SSH_COMMAND core@${HUB_NODE_IP} "grep -v ${HUB_NODE_IP} /etc/resolv.conf | grep nameserver | cut -f2 -d\ ")
}

function grab_api_ingress() {
    # Spoke Cluster Name using the Hub's domain as a base
    cluster=${1}

    grab_domain
    grab_hub_dns
    export SPOKE_API_NAME="api.${cluster}.${HUB_BASEDOMAIN}"
    export SPOKE_API_IP="$(dig @${HUB_NODE_IP} +short ${SPOKE_API_NAME})"
    if [[ "$(echo ${SPOKE_API_IP} | grep -c 'timed out')" == 1 ]]; then
        export SPOKE_API_IP="$(dig +short ${SPOKE_API_NAME})"
        if [[ -z ${SPOKE_API_IP} ]]; then
            echo "CRITICAL ERROR: ${SPOKE_API_NAME} cannot be resolved"
            exit 1
        fi
    fi
    export SPOKE_INGRESS_NAME="apps.${cluster}.${HUB_BASEDOMAIN}"
    export REGISTRY_URL="ztpfw-registry-ztpfw-registry"
    export SPOKE_INGRESS_IP="$(dig @${HUB_NODE_IP} +short ${REGISTRY_URL}.${SPOKE_INGRESS_NAME})"
}

# SPOKES_FILE variable must be exported in the environment
export KUBECONFIG_HUB=${KUBECONFIG}

echo ">>>> Grabbing info from Spokes File"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

export OC_DIS_CATALOG=ztpfw-catalog
export MARKET_NS=openshift-marketplace
export ZTPFW_NS=ztpfw
export OUTPUTDIR=${OUTPUTDIR:-$WORKDIR/build}
export MIRROR_MODE=${MIRROR_MODE:-all}
export SCP_COMMAND='scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q -r'
export SSH_COMMAND='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q'
export PODMAN_LOGIN_CMD='podman login --storage-driver=vfs --tls-verify=false'

[ -d ${OUTPUTDIR} ] || mkdir -p ${OUTPUTDIR}

if [ ! -z ${SPOKES_CONFIG+x} ]; then
    if [ -z "${SPOKES_FILE+x}" ]; then
        export SPOKES_FILE="${OUTPUTDIR}/spokes.yaml"
    fi

    echo "Creating ${SPOKES_FILE} from SPOKES_CONFIG"
    echo $"${SPOKES_CONFIG}" >"${SPOKES_FILE}"
fi

if [ ! -f "${SPOKES_FILE}" ]; then
    echo "File ${SPOKES_FILE} does not exist"
    exit 1
fi

export OC_OCP_VERSION_FULL=$(yq eval ".config.OC_OCP_VERSION" ${SPOKES_FILE})
export OC_OCP_VERSION_MIN=${OC_OCP_VERSION_FULL%.*}
export OC_RHCOS_RELEASE=$(curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OC_OCP_VERSION_FULL}/release.txt | grep 'CoreOS' | cut -d' ' -f4)
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${SPOKES_FILE})
export OC_ODF_VERSION=$(yq eval ".config.OC_ODF_VERSION" ${SPOKES_FILE})
export OC_OCP_TAG=${OC_OCP_VERSION_FULL}"-x86_64"
VERSION_WITHOUT_QUOTES="${OC_OCP_VERSION_FULL%\"}"
VERSION_WITHOUT_QUOTES="${VERSION_WITHOUT_QUOTES#\"}"
export CLUSTERIMAGESET="openshift-v"${VERSION_WITHOUT_QUOTES}
export CLOUD_DEPLOYMENT=$(yq eval ".config.CLOUD_DEPLOYMENT" ${SPOKES_FILE})

if [ -z ${KUBECONFIG+x} ]; then
    echo "Please, provide a path for the hub's KUBECONFIG: It will be created if it doesn't exist"
    exit 1
fi

if [[ ! -f ${KUBECONFIG} && -f "/run/secrets/kubernetes.io/serviceaccount/token" ]]; then
    if [ -z "${KUBECONFIG+x}" ]; then
        export KUBECONFIG="${OUTPUTDIR}/kubeconfig"
    fi
    echo "Kubeconfig file doesn't exist: creating one from token"
    oc config set-credentials spokes-deployer --token=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
elif [[ ! -f ${KUBECONFIG} ]]; then
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
