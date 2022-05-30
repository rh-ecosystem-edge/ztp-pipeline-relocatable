#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function detach_cluster() {
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Dettaching Edge-cluster ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${cluster}
}

function clean_cluster() {
    #####################################################
    # WARNING!
    # Carefully doing the Clean Cluster, we are storing
    # the key files on the edgecluster cluster Namespace and
    # with this function you will delete it
    #####################################################
    # Function to clean cluster from hub
    cluster=${1}
    echo ">> Cleaning Edge-cluster ${cluster} cluster from Hub"
    oc --kubeconfig=${KUBECONFIG_HUB} delete namespace ${cluster}
}

function generate_edgecluster_csr-approver_resources() {
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

function generate_edgecluster_csr-approver_kubeconfig() {

    export EDGE_CSR_KUBECONFIG=${EDGE_SAFE_FOLDER}/ztpfw-csr-approver-config
    export EDGE_CSR_RESOURCES=${EDGE_SAFE_FOLDER}/ztpfw-csr-approver-resources.yaml

    # Generate ServiceAccount and ClusterRole ztpfw-csr-approver
    generate_edgecluster_csr-approver_resources ${EDGE_CSR_RESOURCES}

    # Create resources if they don't exist yet. We need this for multi-node clusters.
    # Then, create the ClusterRoleBinding and final kubeconfig
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f ${EDGE_CSR_RESOURCES}
    oc --kubeconfig=${EDGE_KUBECONFIG} adm policy add-cluster-role-to-user ztpfw-csr-approver -z ztpfw-csr-approver -n openshift-infra
    oc --kubeconfig=${EDGE_KUBECONFIG} serviceaccounts create-kubeconfig ztpfw-csr-approver -n openshift-infra >${EDGE_CSR_KUBECONFIG}
}

function save_files() {
    cluster=${1}
    i=${2}
    cp -f ${EDGE_KUBECONFIG} ${EDGE_KUBEADMIN_PASS} ${EDGE_SAFE_FOLDER}

    # Generate csr-approver resources
    generate_edgecluster_csr-approver_kubeconfig

    for agent in $(oc get agents --kubeconfig=${KUBECONFIG_HUB} -n ${cluster} -o jsonpath='{.items[?(@.status.role=="master")].metadata.name}'); do
        echo
        EDGE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${cluster} ${agent} -o jsonpath={.spec.hostname})
        master=${EDGE_NODE_NAME##*-}
        MAC_EXT_DHCP=$(yq e ".edgeclusters[${i}].${cluster}.master${master}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})
        EDGE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent ${agent} -n ${cluster} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
        NODE_IP=${EDGE_NODE_IP_RAW%%/*}
        if [[ -n ${NODE_IP} ]]; then
            echo "Master Node: ${master}"
            echo "AGENT: ${agent}"
            echo "BMC: ${MAC_EXT_DHCP}"
            echo "IP: ${NODE_IP%%/*}"
            echo ">>>>"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "mkdir -p ~/.kube"
            copy_files_common "${EDGE_CSR_KUBECONFIG}" "${NODE_IP%%/*}" "./.kube/ztpfw-csr-approver-config"
            ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "rm -f ~/.kube/config"
        fi
    done
}

function check_cluster() {
    cluster=${1}
    wait_time=10000

    echo ">>>> Check Edge cluster: ${cluster}"
    echo ">> Check ManagedCluster for Edge: ${cluster}"
    check_resource "managedcluster" "${cluster}" "ManagedClusterConditionAvailable" "edgecluster-deployer" "${KUBECONFIG_HUB}"
    check_resource "managedcluster" "${cluster}" "ManagedClusterImportSucceeded" "edgecluster-deployer" "${KUBECONFIG_HUB}"
    check_resource "managedcluster" "${cluster}" "ManagedClusterJoined" "edgecluster-deployer" "${KUBECONFIG_HUB}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
}

function recover_edgecluster_files() {
    # Function to recover cluster edgecluster files from hub
    cluster=${1}
    echo ">> Recovering Edge-cluster ${cluster} cluster Files"
    extract_kubeconfig_common ${cluster}
    extract_kubeadmin_pass_common ${cluster}
    save_files ${cluster} ${2}
}

function store_rsa_secrets() {
    # Function to save the RSA Key-Pair into the Hub
    cluster=${1}
    echo ">>>> Creating edgecluster cluster Keypair on Hub and Edge-cluster ${cluster} "
    echo ">> Secret name: ${cluster}-keypair"
    echo ">> Namespace: ${cluster}"
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${cluster} create secret generic ${cluster}-keypair --from-file=id_rsa.key=${RSA_KEY_FILE} --from-file=id_rsa.pub=${RSA_PUB_FILE}
    oc --kubeconfig=${EDGE_KUBECONFIG} -n default create secret generic cluster-ssh-keypair --from-file=id_rsa.key=${RSA_KEY_FILE} --from-file=id_rsa.pub=${RSA_PUB_FILE}
}

source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Dettaching clusters"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi
i=0
for edgecluster in ${ALLEDGECLUSTERS}; do
    echo ">> Cluster: ${edgecluster}"
    check_cluster ${edgecluster}
    recover_edgecluster_rsa ${edgecluster}
    recover_edgecluster_files ${edgecluster} ${i}
    store_rsa_secrets ${edgecluster}
    #detach_cluster ${edgecluster}
    i=$((i + 1))
done
