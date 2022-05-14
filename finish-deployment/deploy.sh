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

function generate_spoke_csr-approver_resources() {
    destfile=${1}

    # Generate serviceaccount and clusterrole
    cat <<EOF >${destfile}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ztpfw-csr-approver
  namespace: openshift-infra
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ztpfw-csr-approver
rules:
- apiGroups:
  - certificates.k8s.io
  resources:
  - certificatesigningrequests
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - certificates.k8s.io
  resources:
  - certificatesigningrequests/approval
  verbs:
  - update
- apiGroups:
  - certificates.k8s.io
  resources:
  - signers
  verbs:
  - approve
EOF
}

function generate_spoke_csr-approver_kubeconfig() {

    export SPOKE_CSR_KUBECONFIG=${SPOKE_SAFE_FOLDER}/ztpfw-csr-approver-config
    export SPOKE_CSR_RESOURCES=${SPOKE_SAFE_FOLDER}/ztpfw-csr-approver-resources.yaml

    # Generate ServiceAccount and ClusterRole ztpfw-csr-approver
    generate_spoke_csr-approver_resources ${SPOKE_CSR_RESOURCES}

    # Create resources if they don't exist yet. We need this for multi-node clusters.
    # Then, create the ClusterRoleBinding and final kubeconfig
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f ${SPOKE_CSR_RESOURCES}
    oc --kubeconfig=${SPOKE_KUBECONFIG} adm policy add-cluster-role-to-user ztpfw-csr-approver -z ztpfw-csr-approver -n openshift-infra
    oc --kubeconfig=${SPOKE_KUBECONFIG} serviceaccounts create-kubeconfig ztpfw-csr-approver >${SPOKE_CSR_KUBECONFIG}
}

function save_files() {
    cluster=${1}
    i=${2}
    cp -f ${SPOKE_KUBECONFIG} ${SPOKE_KUBEADMIN_PASS} ${SPOKE_SAFE_FOLDER}

    # Generate csr-approver resources
    generate_spoke_csr-approver_kubeconfig

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
            echo "BMC: ${MAC_EXT_DHCP}"
            echo "IP: ${NODE_IP%%/*}"
            echo ">>>>"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "mkdir -p ~/.kube"
            copy_files_common "${SPOKE_CSR_KUBECONFIG}" "${NODE_IP%%/*}" "./.kube/ztpfw-csr-approver-config"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "rm -f ~/.kube/config"
        fi
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
    recover_spoke_files ${spoke} ${i}
    store_rsa_secrets ${spoke}
    #detach_cluster ${spoke}
    i=$((i + 1))
done
