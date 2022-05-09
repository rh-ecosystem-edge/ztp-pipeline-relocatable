#!/bin/sh
# Set path during systemd execution
export PATH=/root/.local/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Wait for API to come online
until [ $(curl -k -s https://api:6443/version?timeout=10s | jq -r '.major' | grep -v null | wc -l) -eq 1 ]; do
    echo "Waiting for API..."
    sleep 10
done

# Begin looking for and signing CSRs to activate nodes
export KUBECONFIG="/var/home/core/.kube/ztpfw-csr-approver-config"

    # Fail if ztpfw kubeconfig does not exist
    if [ ! -f ${KUBECONFIG} ] 
        echo "ERROR: Could not find ztpfw-csr-approver-config kubeconfig file for the cluster"
        exit 1
    fi

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
