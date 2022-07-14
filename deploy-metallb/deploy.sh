#!/usr/bin/env bash

set -o pipefail
set -o nounset
#set -o errexit
set -m

function extract_kubeconfig() {
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${1} secret/${1}-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
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
            envsubst <${SOURCE_FILE} | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
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

    echo ">>>> Verifying Edge-cluster cluster: ${cluster}"
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

        if [[ $(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc -n ${NS} get ${KIND} -l ${NAME} --no-headers | grep -i "${STATUS}" | wc -l") -ge 1 ]]; then
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

    echo ">>>> Verifying Edge-cluster cluster: ${cluster}"
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

        if [[ $(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc -n ${NS} get ${KIND} ${NAME} --no-headers | egrep -i "${STATUS}" | wc -l") -ge 1 ]]; then
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

    # Each call to this function affects to 1 Edge-cluster at the same time and the ${index} is the number of the edgecluster
    index=${1}
    echo ">> Rendering Manifests for Edge-cluster ${index}"

    # Render the subscription to be connected or disconnected (assuming sno is connected)
    export NUM_M=$(yq e ".edgeclusters[0].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l | xargs)
    if [ "${NUM_M}" -eq "3" ]; then # 3 masters and disconnected
        sed -i "s/CHANGE_SOURCE/ztpfw-catalog/g" manifests/03-MLB-Subscription.yaml
        sed -i "s/CHANGE_SOURCE/ztpfw-catalog/g" manifests/03-NMS-Subscription.yaml
    else # sno is connected so the source should be upstream
        sed -i "s/CHANGE_SOURCE/redhat-operators/g" manifests/03-MLB-Subscription.yaml
        sed -i "s/CHANGE_SOURCE/redhat-operators/g" manifests/03-NMS-Subscription.yaml
    fi

    # Render NNCP Manifests
    for master in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l) - 1)))); do
        export NODENAME=ztpfw-${edgecluster}-master-${master}
        echo "Rendering NNCP for: ${NODENAME}"
        export NIC_EXT_DHCP=$(yq e ".edgeclusters[${index}].${edgecluster}.master${master}.nic_ext_dhcp" ${EDGECLUSTERS_FILE})
        render_file manifests/nncp.yaml ${OUTPUTDIR}/${edgecluster}-nncp-${NODENAME}.yaml
        files+=(${OUTPUTDIR}/${edgecluster}-nncp-${NODENAME}.yaml)
    done

    # Render MetalLB Manifests
    grab_api_ingress ${edgecluster}

    export METALLB_API_IP="${EDGE_API_IP}"
    export METALLB_INGRESS_IP="${EDGE_INGRESS_IP}"

    if [[ -z ${METALLB_API_IP} ]]; then
        echo "You need to add the 'metallb_api_ip' field in your Edge-cluster cluster definition"
        exit 1
    fi

    if [[ -z ${METALLB_INGRESS_IP} ]]; then
        echo "You need to add the 'metallb_ingress_ip' field in your Edge-cluster cluster definition"
        exit 1
    fi
    echo ">> Rendering MetalLB for: ${edgecluster}"
    # API First
    export SVC_NAME='api-public-ip'
    export METALLB_IP=${METALLB_API_IP}
    render_file manifests/address_pool.yaml ${OUTPUTDIR}/${edgecluster}-metallb-api.yaml
    files+=(${OUTPUTDIR}/${edgecluster}-metallb-api.yaml)
    render_file manifests/metallb-api-svc.yaml ${OUTPUTDIR}/${edgecluster}-metallb-api-svc.yaml
    files+=(${OUTPUTDIR}/${edgecluster}-metallb-api-svc.yaml)

    # Ingress First
    export SVC_NAME='ingress-public-ip'
    export METALLB_IP=${METALLB_INGRESS_IP}
    render_file manifests/address_pool.yaml ${OUTPUTDIR}/${edgecluster}-metallb-ingress.yaml
    files+=(${OUTPUTDIR}/${edgecluster}-metallb-ingress.yaml)
    render_file manifests/metallb-ingress-svc.yaml ${OUTPUTDIR}/${edgecluster}-metallb-ingress-svc.yaml
    files+=(${OUTPUTDIR}/${edgecluster}-metallb-ingress-svc.yaml)
    echo ">> Rendering Done!"
    echo
}

function grab_master_ext_ips() {
    edgecluster=${1}
    local edgeclusternumber=${2}

    ## Grab 1 master and 1 IP
    agent=$(oc get agents --kubeconfig=${KUBECONFIG_HUB} -n ${edgecluster} -o jsonpath='{.items[?(@.status.role=="master")].metadata.name}' | awk '{print $1}')

    export EDGE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${edgecluster} ${agent} -o jsonpath={.spec.hostname})
    master=${EDGE_NODE_NAME##*-}
    export MAC_EXT_DHCP=$(yq e ".edgeclusters[${edgeclusternumber}].${edgecluster}.master${master}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})
    ## HAY QUE PROBAR ESTO
    EDGE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent ${agent} -n ${edgecluster} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
    export EDGE_NODE_IP=${EDGE_NODE_IP_RAW%%/*}
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
    echo ">> Checking external access to the edgecluster ${cluster}"
    oc --kubeconfig=${EDGE_KUBECONFIG} get nodes --no-headers
    if [[ ${?} != 0 ]]; then
        echo "ERROR: You cannot access ${cluster} edgecluster cluster externally"
        exit 1
    fi
    echo ">> external access with edgecluster ${cluster} Verified"
    echo
}

function check_connectivity() {
    IP=${1}
    echo ">> Checking connectivity against: ${IP}"

    if [[ -z ${IP} ]]; then
        echo "ERROR: Variable \${IP} empty, this could means that the ARP does not match with the MAC address provided in the Edge-cluster File ${EDGECLUSTERS_FILE}"
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

    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        export ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    # This var reflects the edgecluster cluster you're working with
    index=0
    wait_time=240

    for edgecluster in ${ALLEDGECLUSTERS}; do
        echo ">>>> Starting the MetalLB process for Edge-cluster: ${edgecluster} in position ${index}"
        echo ">> Extract Kubeconfig for ${edgecluster}"
        extract_kubeconfig ${edgecluster}
        grab_master_ext_ips ${edgecluster} ${index}
        recover_edgecluster_rsa ${edgecluster}
        check_connectivity "${EDGE_NODE_IP}"
        render_manifests ${index}

        # Remote working
        echo ">> Copying files to the Edge-cluster ${edgecluster}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "mkdir -p ~/manifests ~/.kube"
        for _file in ${files[@]}; do
            copy_files "${_file}" "${EDGE_NODE_IP}" "./manifests/"
        done
        copy_files "./manifests/*.yaml" "${EDGE_NODE_IP}" "./manifests/"
        copy_files "${EDGE_KUBECONFIG}" "${EDGE_NODE_IP}" "./.kube/config"
        echo

        # "Patch bz https://bugzilla.redhat.com/show_bug.cgi?id=2106840"
        echo ">> Patching the MetalLB operator"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP}  "oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-nmstate:nmstate-operator"

        echo ">> Deploying NMState and MetalLB for ${edgecluster}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/01-NMS-Namespace.yaml -f manifests/02-NMS-OperatorGroup.yaml -f manifests/01-MLB-Namespace.yaml -f manifests/02-MLB-OperatorGroup.yaml"
        sleep 2
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/03-NMS-Subscription.yaml -f manifests/03-MLB-Subscription.yaml"
        sleep 10
        echo

        verify_remote_pod ${edgecluster} "openshift-nmstate" "pod" "name=kubernetes-nmstate-operator"
        # This empty quotes is because we don't know the pod name for MetalLB
        verify_remote_pod ${edgecluster} "metallb" "pod" "control-plane=controller-manager"
        # These empty quotes (down bellow) are just to verify the CRDs and we don't want a 'running'
        verify_remote_resource ${edgecluster} "default" "crd" "nmstates.nmstate.io" "."
        verify_remote_resource ${edgecluster} "default" "crd" "metallbs.metallb.io" "."
        echo

        echo ">>>> Deploying NMState Operand for ${edgecluster}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/04-NMS-Operand.yaml"
        sleep 2
        for dep in {nmstate-cert-manager,nmstate-webhook}; do
            verify_remote_resource ${edgecluster} "openshift-nmstate" "deployment.apps" ${dep} "."
        done

        # Waiting a bit to avoid webhook readyness issue
        # Internal error occurred: failed calling webhook "nodenetworkconfigurationpolicies-mutate.nmstate.io"
        sleep 60

        for master in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l) - 1)))); do
            export NODENAME=ztpfw-${edgecluster}-master-${master}
            export FILENAME=${edgecluster}-nncp-${NODENAME}
            # I've been forced to do that, don't blame me :(
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/${FILENAME}.yaml"
            verify_remote_resource ${edgecluster} "default" "nncp" "${NODENAME}-nncp" "Available"
        done
        echo

        echo ">> Deploying MetalLB Operand for ${edgecluster}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/04-MLB-Operand.yaml"
        sleep 2
        verify_remote_resource ${edgecluster} "metallb" "deployment.apps" "controller" "."
        verify_remote_pod ${edgecluster} "metallb" "pod" "component=speaker"

        echo ">> Deploying MetalLB AddressPools and Services for ${edgecluster}"
        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc apply -f manifests/${edgecluster}-metallb-api.yaml -f manifests/${edgecluster}-metallb-api-svc.yaml -f manifests/${edgecluster}-metallb-ingress-svc.yaml -f manifests/${edgecluster}-metallb-ingress.yaml"
        echo

        sleep 2
        verify_remote_resource ${edgecluster} "metallb" "AddressPool" "api-public-ip" "."
        verify_remote_resource ${edgecluster} "openshift-kube-apiserver" "service" "metallb-api" "."
        verify_remote_resource ${edgecluster} "metallb" "AddressPool" "ingress-public-ip" "."
        verify_remote_resource ${edgecluster} "openshift-ingress" "service" "metallb-ingress" "."
        echo
        check_external_access ${edgecluster}
        echo 'Patch external CatalogSources'
        oc --kubeconfig=${EDGE_KUBECONFIG} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
        echo ">>>> Edge-cluster ${edgecluster} finished!"
        let index++
    done
else
    echo ">>>> This is step is not needed. Skipping..."
fi
exit 0
