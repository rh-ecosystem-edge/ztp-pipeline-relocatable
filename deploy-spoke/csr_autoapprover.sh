#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Generate CSR resources
function generate_csr_resources(){
destfolder=${1}

    # Generate serviceaccount and clusterrole
    cat <<EOF >${destfolder}/csr-resources.yaml
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

# Wait for API to come online
until [ $(curl -k -s https://api:6443/version?timeout=10s | jq -r '.major' | grep -v null | wc -l) -eq 1 ]; do
    echo "Waiting for API..."
    sleep 10
done

# Begin looking for and signing CSRs to activate nodes
export CSR_KUBECONFIG="/var/home/core/.kube/csr-config"

if [ -f ${CSR_KUBECONFIG} ] 
then
    export KUBECONFIG="${CSR_KUBECONFIG}"
else
    export KUBECONFIG="/var/home/core/.kube/config"
    export TEMPDIR="/var/home/core/.temp"

    if [ ! -f "${KUBECONFIG}" ]; then
        echo "ERROR: Could not find system:admin kubeconfig file for cluster"
        exit 1
    fi

    # Generate ServiceAccount and ClusterRole ztpfw-csr-approver
    mkdir -p "${TEMPDIR}"
    generate_csr_resources "${TEMPDIR}"

    # Create resources if they don't exist yet. We need this for multi-node clusters.
    # Then, create the ClusterRoleBinding and final kubeconfig
    oc --kubeconfig=${KUBECONFIG} apply -f "${TEMPDIR}"/csr-resources.yaml
    oc --kubeconfig=${KUBECONFIG} adm policy add-cluster-role-to-user ztpfw-csr-approver -z ztpfw-csr-approver -n openshift-infra
    oc --kubeconfig=${KUBECONFIG} serviceaccounts create-kubeconfig ztpfw-csr-approver > "${CSR_KUBECONFIG}"

    # Clean system:admin kubeconfig and tempdir
    rm -f "${TEMPDIR}"
    rm -f "${KUBECONFIG}"

    # Set CSR_KUBECONFIG as KUBECONFIG to continue normal node execution
    export KUBECONFIG="${CSR_KUBECONFIG}"
fi

count=30
while [ ${count} -gt 0 ]; do

    # We need to get the Pending CSR's and work over them to approve the individual certificates
    oc get csr | grep Pending | grep -E 'kube-apiserver-client|kubelet-serving' | awk '{print $1}' | xargs oc adm certificate approve

    if [ $(oc get csr | grep Approved | grep -v Issued | wc -l) -gt 0 ]; then
        echo "CSR(s) approved and issued"
        sleep 10
        break
    else
        echo "No pending/unissued certificate requests (CSR) found."
        count=$((count - 1))
    fi
    sleep 20

done
