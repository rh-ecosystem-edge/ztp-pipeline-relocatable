#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Wait for API to come online
until [ $(curl -k -s https://api:6443/version?timeout=10s | jq -r '.major' | grep -v null | wc -l) -eq 1 ]; do
    echo "Waiting for API..."
    sleep 10
done

# Begin looking for and signing CSRs to activate nodes
CLUSTER_DATA_FOLDER="/var/home/core/cluster_access_data"
export KUBECONFIG=$(ls $CLUSTER_DATA_FOLDER/*/kubeconfig-* | head -1)

if [ ! -f "${KUBECONFIG}" ]; then
    echo "ERROR: Could not find kubeconfig file for cluster"
    exit 1
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

 if [ $(oc get csr | grep Approved | grep -v Issued | wc -l) -gt 0 ]; then
    rm ${KUBECONFIG}
    echo "Kubeconfig file removed"
    systemctl disable csr-approver
    echo "csr-approver service disabled"
    exit 0
fi