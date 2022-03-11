#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function check_managedcluster() {
    cluster=${1}
    wait_time=${2}
    condition=${3}
    desired_status=${4}

    timeout=0
    ready=false

    while [ "${timeout}" -lt "${wait_time}" ]; do
        if [[ $(oc --kubeconfig=${KUBECONFIG_HUB} get managedcluster ${cluster} -o jsonpath="{.status.conditions[?(@.type==\"${condition}\")].status}") == "${desired_status}" ]]; then
            ready=true
            break
        fi
        echo ">> Waiting for ManagedCluster"
        echo "Spoke: ${cluster}"
        echo "Condition: ${condition}"
        echo "Desired State: ${desired_status}"
        echo
        timeout=$((timeout + 10))
        sleep 10
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for Spoke ${cluster} on condition ${condition}"
        echo "Expected: ${desired_status} Current: $(oc --kubeconfig=${KUBECONFIG_HUB} get managedcluster ${cluster} -o jsonpath="{.status.conditions[?(@.type==\"${condition}\")].status}")"
        exit 1
    else
        echo "ManagedCluster for ${cluster} condition: ${condition} verified"
    fi
}

function detach_cluster() {
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Dettaching Spoke ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${cluster}
}

function clean_cluster() {
    #####################################################
    # WARNING!
    # Carefully doing the Clean Cluster, we are storing
    # the key files on the spoke cluster Namespace and
    # with this function you will delete it
    #####################################################
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Cleaning Spoke ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete namespace ${cluster}
}

function save_files() {
    cluster=${1}
    i=${2}
    cp -f ${SPOKE_KUBECONFIG} ${SPOKE_KUBEADMIN_PASS} ${SPOKE_SAFE_FOLDER}

    for master in 0 1 2; do
        EXT_MAC_ADDR=$(yq eval ".spokes[${i}].${cluster}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
        echo ""
        echo ">>>> Copying ${cluster} Kubeconfig to Master ${master} Node"
        for agent in $(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${cluster} agent -o name); do
            NODE_IP=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${cluster} ${agent} -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${EXT_MAC_ADDR}\")].ipV4Addresses[0]}")
            if [[ -n ${NODE_IP} ]]; then
                echo "Master Node: ${master}"
                echo "AGENT: ${agent}"
                echo "BMC: ${EXT_MAC_ADDR}"
                echo "IP: ${NODE_IP%%/*}"
                echo ">>>>"
                ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "mkdir -p ~/.kube"
                copy_files_common "${SPOKE_KUBECONFIG}" "${NODE_IP%%/*}" "./.kube/config"
            fi
        done
    done
}

function check_cluster() {
    cluster=${1}
    wait_time=10000

    echo ">>>> Check spoke cluster: ${cluster}"
    echo ">> Check ManagedCluster for spoke: ${cluster}"
    check_managedcluster "${cluster}" "${wait_time}" "ManagedClusterConditionAvailable" "True"
    check_managedcluster "${cluster}" "${wait_time}" "ManagedClusterImportSucceeded" "True"
    check_managedcluster "${cluster}" "${wait_time}" "ManagedClusterJoined" "True"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
}

function recover_spoke_files() {
    # Function to recover cluster spoke files from hub
    cluster=${1}
    echo ">> Recovering Spoke ${cluster} cluster Files"
    extract_kubeconfig_common ${cluster}
    extract_kubeadmin_pass_common ${cluster}
    save_files ${cluster} ${2}
}

function store_rsa_secrets() {
    # Function to save the RSA Key-Pair into the Hub
    cluster=${1}
    echo ">>>> Creating spoke cluster Keypair on Hub and Spoke ${cluster} "
    echo ">> Secret name: ${cluster}-keypair"
    echo ">> Namespace: ${cluster}"
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${cluster} create secret generic ${cluster}-keypair --from-file=id_rsa.key=${RSA_KEY_FILE} --from-file=id_rsa.pub=${RSA_PUB_FILE}
    oc --kubeconfig=${SPOKE_KUBECONFIG} -n default create secret generic cluster-ssh-keypair --from-file=id_rsa.key=${RSA_KEY_FILE} --from-file=id_rsa.pub=${RSA_PUB_FILE}
}

source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Dettaching clusters"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi
i=0
for spoke in ${ALLSPOKES}; do
    echo ">> Cluster: ${spoke}"
    check_cluster ${spoke}
    recover_spoke_rsa ${spoke}
    recover_spoke_files ${spoke} $i
    store_rsa_secrets ${spoke}
    #detach_cluster ${spoke}
    i=$((i+1))
done
