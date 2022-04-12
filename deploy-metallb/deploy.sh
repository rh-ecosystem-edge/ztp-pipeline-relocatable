#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
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
    ready=false
    if [[ ${DESTINATION_FILE} == "" ]]; then
        for try in seq {0..10}; do
            envsubst <${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
            if [[ $? == 0 ]]; then
                ready=true
                break
            fi
            echo "Retrying the File Rendering (${try}/10): ${SOURCE_FILE}"
            sleep 5
        done
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function verify_remote_pod() {
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
        if [[ ${DEBUG} == 'true' ]]; then
            echo
            echo "cluster: ${cluster}"
            echo "NS: ${NS}"
            echo "KIND: ${KIND}"
            echo "NAME: ${NAME}"
            echo "STATUS: ${STATUS}"
            echo
        fi

        if [[ $(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc -n ${NS} get ${KIND} -l ${NAME} --no-headers | grep -i "${STATUS}" | wc -l") -ge 1 ]]; then
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
        if [[ ${DEBUG} == 'true' ]]; then
            echo
            echo "cluster: ${cluster}"
            echo "NS: ${NS}"
            echo "KIND: ${KIND}"
            echo "NAME: ${NAME}"
            echo "STATUS: ${STATUS}"
            echo
        fi

        if [[ $(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc -n ${NS} get ${KIND} ${NAME} --no-headers | egrep -i "${STATUS}" | wc -l") -ge 1 ]]; then
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
    echo ">> Rendering Manifests for Spoke ${index}"

    # Render NNCP Manifests
    for master in $(echo $(seq 0 $(($(yq eval ".spokes[${index}].[]|keys" ${SPOKES_FILE} | grep master | wc -l) - 1)))); do
        export NODENAME=ztpfw-${spoke}-master-${master}
        echo "Rendering NNCP for: ${NODENAME}"
        export NIC_EXT_DHCP=$(yq e ".spokes[${index}].${spoke}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})
        render_file manifests/nncp.yaml ${OUTPUTDIR}/${spoke}-nncp-${NODENAME}.yaml
        files+=(${OUTPUTDIR}/${spoke}-nncp-${NODENAME}.yaml)
    done

    # Render MetalLB Manifests
    grab_api_ingress ${spoke}

    export METALLB_API_IP="${SPOKE_API_IP}"
    export METALLB_INGRESS_IP="${SPOKE_INGRESS_IP}"

    if [[ -z ${METALLB_API_IP} ]]; then
        echo "You need to add the 'metallb_api_ip' field in your Spoke cluster definition"
        exit 1
    fi

    if [[ -z ${METALLB_INGRESS_IP} ]]; then
        echo "You need to add the 'metallb_ingress_ip' field in your Spoke cluster definition"
        exit 1
    fi
    echo ">> Rendering MetalLB for: ${spoke}"
    # API First
    export SVC_NAME='api-public-ip'
    export METALLB_IP=${METALLB_API_IP}
    render_file manifests/address_pool.yaml ${OUTPUTDIR}/${spoke}-metallb-api.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-api.yaml)
    render_file manifests/metallb-api-svc.yaml ${OUTPUTDIR}/${spoke}-metallb-api-svc.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-api-svc.yaml)

    # Ingress First
    export SVC_NAME='ingress-public-ip'
    export METALLB_IP=${METALLB_INGRESS_IP}
    render_file manifests/address_pool.yaml ${OUTPUTDIR}/${spoke}-metallb-ingress.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-ingress.yaml)
    render_file manifests/metallb-ingress-svc.yaml ${OUTPUTDIR}/${spoke}-metallb-ingress-svc.yaml
    files+=(${OUTPUTDIR}/${spoke}-metallb-ingress-svc.yaml)
    echo ">> Rendering Done!"
    echo
}

function grab_master_ext_ips() {
    spoke=${1}
    local spokenumber=${2}

    ## Grab 1 master and 1 IP
    agent=$(oc --kubeconfig=${KUBECONFIG_HUB} get agents -n ${spoke} --no-headers -o name | head -1)
    export SPOKE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${spoke} ${agent} -o jsonpath={.spec.hostname})
    master=${SPOKE_NODE_NAME##*-}
    export MAC_EXT_DHCP=$(yq e ".spokes[${spokenumber}].${spoke}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
    ## HAY QUE PROBAR ESTO
    SPOKE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get ${agent} -n ${spoke} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
    export SPOKE_NODE_IP=${SPOKE_NODE_IP_RAW%%/*}
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
    ${SCP_COMMAND} -i ${RSA_KEY_FILE} ${src_files[@]} core@${dst_node}:${dst_folder}
}

function check_external_access() {
    cluster=${1}
    echo ">> Checking external access to the spoke ${cluster}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} get nodes --no-headers
    if [[ ${?} != 0 ]]; then
        echo "ERROR: You cannot access ${cluster} spoke cluster externally"
        exit 1
    fi
    echo ">> external access with spoke ${cluster} Verified"
    echo
}

function check_connectivity() {
    IP=${1}
    echo ">> Checking connectivity against: ${IP}"

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
    echo
}

source ${WORKDIR}/shared-utils/common.sh
export DEBUG=false

if ! ./verify.sh; then
    echo ">>>> Deploying NMState and MetalLB operators"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    if [[ -z ${ALLSPOKES} ]]; then
        export ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    # This var reflects the spoke cluster you're working with
    index=0
    wait_time=240

    for spoke in ${ALLSPOKES}; do
        echo ">>>> Starting the MetalLB process for Spoke: ${spoke} in position ${index}"
        echo ">> Extract Kubeconfig for ${spoke}"
        extract_kubeconfig ${spoke}
        grab_master_ext_ips ${spoke} ${index}
        recover_spoke_rsa ${spoke}
        check_connectivity "${SPOKE_NODE_IP}"
        render_manifests ${index}

        # Remote working
        echo ">> Copying files to the Spoke ${spoke}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "mkdir -p ~/manifests ~/.kube"
        for _file in ${files[@]}; do
            copy_files "${_file}" "${SPOKE_NODE_IP}" "./manifests/"
        done
        copy_files "./manifests/*.yaml" "${SPOKE_NODE_IP}" "./manifests/"
        copy_files "${SPOKE_KUBECONFIG}" "${SPOKE_NODE_IP}" "./.kube/config"
        echo

        echo ">> Deploying NMState and MetalLB for ${spoke}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/01-NMS-Namespace.yaml -f manifests/02-NMS-OperatorGroup.yaml -f manifests/01-MLB-Namespace.yaml -f manifests/02-MLB-OperatorGroup.yaml"
        sleep 2
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/03-NMS-Subscription.yaml -f manifests/03-MLB-Subscription.yaml"
        sleep 10
        echo

        verify_remote_pod ${spoke} "openshift-nmstate" "pod" "name=kubernetes-nmstate-operator"
        # This empty quotes is because we don't know the pod name for MetalLB
        verify_remote_pod ${spoke} "metallb" "pod" "control-plane=controller-manager"
        # These empty quotes (down bellow) are just to verify the CRDs and we don't want a 'running'
        verify_remote_resource ${spoke} "default" "crd" "nmstates.nmstate.io" "."
        verify_remote_resource ${spoke} "default" "crd" "metallbs.metallb.io" "."
        echo

        echo ">>>> Deploying NMState Operand for ${spoke}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/04-NMS-Operand.yaml"
        sleep 2
        for dep in {nmstate-cert-manager,nmstate-webhook}; do
            verify_remote_resource ${spoke} "openshift-nmstate" "deployment.apps" ${dep} "."
        done

        # Waiting a bit to avoid webhook readyness issue
        # Internal error occurred: failed calling webhook "nodenetworkconfigurationpolicies-mutate.nmstate.io"
        sleep 60

        for master in $(echo $(seq 0 $(($(yq eval ".spokes[${index}].[]|keys" ${SPOKES_FILE} | grep master | wc -l) - 1)))); do
            export NODENAME=ztpfw-${spoke}-master-${master}
            export FILENAME=${spoke}-nncp-${NODENAME}
            # I've been forced to do that, don't blame me :(
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/${FILENAME}.yaml"
            verify_remote_resource ${spoke} "default" "nncp" "${NODENAME}-nncp" "Available"
        done
        echo

        echo ">> Deploying MetalLB Operand for ${spoke}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/04-MLB-Operand.yaml"
        sleep 2
        verify_remote_resource ${spoke} "metallb" "deployment.apps" "controller" "."
        verify_remote_pod ${spoke} "metallb" "pod" "component=speaker"

        echo ">> Deploying MetalLB AddressPools and Services for ${spoke}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc apply -f manifests/${spoke}-metallb-api.yaml -f manifests/${spoke}-metallb-api-svc.yaml -f manifests/${spoke}-metallb-ingress-svc.yaml -f manifests/${spoke}-metallb-ingress.yaml"
        echo

        sleep 2
        verify_remote_resource ${spoke} "metallb" "AddressPool" "api-public-ip" "."
        verify_remote_resource ${spoke} "openshift-kube-apiserver" "service" "metallb-api" "."
        verify_remote_resource ${spoke} "metallb" "AddressPool" "ingress-public-ip" "."
        verify_remote_resource ${spoke} "openshift-ingress" "service" "metallb-ingress" "."
        echo
        check_external_access ${spoke}
        echo 'Patch external CatalogSources'
        oc --kubeconfig=${SPOKE_KUBECONFIG} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
        echo ">>>> Spoke ${spoke} finished!"
        let index++
    done
else
    echo ">>>> This is step is not needed. Skipping..."
fi
#exit 0
