#!/bin/bash

set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${1} secret/${1}-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

function render_file() {
    SOURCE_FILE=${1}
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function verify_remote_resource() {
    cluster=${1}
    NS=${2}
    KIND=${3}
    NAME=${4}
    STATUS=${5:-running}

    echo ">>>> Verifying Spoke cluster: ${cluster}"
    echo ">>>> Wait until ${KIND} ${NAME} is ready for ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "${timeout}" -lt "240" ]; do
        if [[ $(${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc -n ${NS} get ${KIND} ${NAME} --no-headers | grep -i "${STATUS}" | wc -l") -ge 1 ]]; then
            ready=true
            break
        fi
        sleep 1
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "timeout waiting for ${KIND} ${NAME}"
        exit 1
    fi
}

function render_manifests() {
    # Files rendered will be stored in this array
    declare -ga files=()

    # Each call to this function affects to 1 Spoke at the same time and the ${index} is the number of the spoke
    index=${1}
    echo "Rendering Manifests for Spoke ${index}"

    # Render NNCP Manifests
    for master in 0 1 2; do
        export NODENAME=kubeframe-spoke-${index}-master-${master}
        echo "Rendering NNCP for: ${NODENAME}"
        export NIC_EXT_DHCP=$(yq e ".spokes[\$i].${spoke}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})
        render_file manifests/nncp.yaml ${OUTPUTDIR}/${spoke}-nncp-${NODENAME}.yaml
        files+=(${OUTPUTDIR}/${spoke}-nncp-${NODENAME}.yaml)
    done

    # Render MetalLB Manifests
    export METALLB_IP="$(yq e ".spokes[$i].${spoke}.metallb_ip" ${SPOKES_FILE})"

    if [[ -z ${METALLB_IP} ]]; then
        echo "You need to add the 'metallb_ip' field in your Spoke cluster definition"
        exit 1
    fi
    echo "Rendering MetalLB for: ${spoke}"
    render_file manifests/metallb.yaml ${OUTPUTDIR}/${spoke}-metallb-api.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-api.yaml)
    render_file manifests/metallb-service.yaml ${OUTPUTDIR}/${spoke}-metallb-service.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-service.yaml)
    echo "Rendering Done!"
}

function grab_master_ext_ips() {
    spoke=${1}

    ## Grab 1 master and 1 IP
    agent=$(oc --kubeconfig=${KUBECONFIG_HUB} get agents -n ${spoke} --no-headers -o name | head -1)
    export SPOKE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${spoke} ${agent} -o jsonpath={.spec.hostname})
    master=${SPOKE_NODE_NAME##*-}
    export MAC_EXT_DHCP=$(yq e ".spokes[\$i].${spoke}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
    ## HAY QUE PROBAR ESTO
    export SPOKE_NODE_IP=$(oc --kubeconfig=${KUBECONFIG_HUB} get ${agent} -n ${spoke} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress=="${MAC_EXT_DHCP}")].ipV4Addresses[0]}")
}

function copy_files() {
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
    echo "Done!"
}

function check_connectivity() {
    IP=${1}
    echo "Checking connectivity against: ${IP}"

    if [[ -z ${IP} ]]; then
        echo "ERROR: Variable \${IP} empty, this could means that the ARP does not match with the MAC address provided in the Spoke File ${SPOKES_FILE}"
        exit 1
    fi

    ping ${IP} -c4 -W1 2>&1 >/dev/null
    RC=${?}

    if [[ ${RC} -eq 0 ]]; then
        export CHECKED_IP='available'
        echo "Connectivity validated!"
    else
        export CHECKED_IP='unreachable'
        echo "ERROR: IP ${IP} Unreachable!"
        exit 1
    fi
}

source ${WORKDIR}/shared-utils/common.sh
echo ">>>> Deploying NMState and MetalLB operators"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    export ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

# This var reflects the spoke cluster you're working with
index=0

for spoke in ${ALLSPOKES}; do
    echo ">>>> Starting the MetalLB process for Spoke: ${Spoke} in position ${index}"
    echo ">> Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}
    grab_master_ext_ips ${spoke}
    check_connectivity "${SPOKE_NODE_IP}"
    render_manifests ${index}

    # Remote working
    ${SSH_COMMAND} core@${SPOKE_NODE_IP} "mkdir -p ~/manifests ~/.kube"
    copy_files "${files[@]}" "${SPOKE_NODE_IP}" "./manifests/"
    copy_files "./manifests/*.yaml" "${SPOKE_NODE_IP}" "./manifests/"
    copy_files "${SPOKE_KUBECONFIG}" "${SPOKE_NODE_IP}" "./.kube/config"

    echo ">> Deploying NMState and MetalLB for ${spoke}"
    ${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc apply -f manifests/01-NMS-Namespace.yaml -f manifests/02-NMS-OperatorGroup.yaml -f manifests/01-MLB-Namespace.yaml -f manifests/02-MLB-OperatorGroup.yaml"
    sleep 2
    ${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc apply -f manifests/03-NMS-Subscription.yaml -f manifests/03-MLB-Subscription.yaml"
    sleep 10

    verify_remote_resource ${spoke} "openshift-nmstate" "pod" "nmstate-operator"
    # This empty quotes is because we don't know the pod name for MetalLB
    verify_remote_resource ${spoke} "metallb" "pod" " "
    # These empty quotes (down bellow) are just to verify the CRDs and we don't want a 'running'
    verify_remote_resource ${spoke} "default" "crd" "nmstates.nmstate.io" " "
    verify_remote_resource ${spoke} "default" "crd" "MetalLB" " "

    echo ">>>> Deploying NMState Operand for ${spoke}"
    ${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc apply -f manifests/04-NMS-Operand.yaml"
    sleep 2
    for dep in {nmstate-cert-manager,nmstate-webhook}; do
        verify_remote_resource ${spoke} "openshift-nmstate" "dep" ${dep}
    done

    for master in 0 1 2; do
        NODENAME="${spoke}-nncp-kubeframe-spoke-${index}-master-${master}"
        # I've been forced to do that, don't blame me :(
        ${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc apply -f manifests/${NODENAME}.yaml"
        verify_remote_resource ${spoke} "default" "nncp" "${NODENAME}" "Available"
    done

    echo ">>>> Deploying MetalLB API for ${spoke}"
    ${SSH_COMMAND} core@${SPOKE_NODE_IP} "oc apply -f manifests/${spoke}-metallb-api.yaml -f manifests/${spoke}-metallb-service.yaml"
    sleep 2
    verify_remote_resource ${spoke} "metallb" "AddressPool" "api-public-ip" " "
    verify_remote_resource ${spoke} "metallb" "service" "metallb-api" " "

    echo ">>>> Spoke ${Spoke} done"
    let index++
done
