#!/bin/sh

# Wait for API to come online
until [ $(curl -k -s https://api:6443/version?timeout=10s | jq -r '.major' | grep -v null | wc -l) -eq 1 ]
do
  echo "Waiting for API..."
  sleep 10
done

# Begin looking for and signing CSRs to activate nodes
CLUSTER_DATA_FOLDER="/var/home/core/cluster_access_data"
SPOKE_KUBECONFIG=$(ls $CLUSTER_DATA_FOLDER/*/kubeconfig-*|head -1)


if [ -f "${SPOKE_KUBECONFIG}" ]; then
  echo "ERROR: Could not find kubeconfig file for cluster"
  exit 1
fi

count=30
while [ ${count} -gt 0 ]
do

  oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | grep -E "kubelet-serving|kube-apiserver-client-kubelet" | xargs oc adm certificate approve

  if [ $(oc get csr --kubeconfig "${SPOKE_KUBECONFIG}" | grep Approved | grep -v Issued | wc -l) -gt 0 ]; then
    echo "Waiting for certificate requests and issued certificates..."
  else
    echo "No pending/unissued certificate requests (CSR) found."
    count=$((${count}-1))
  fi
  sleep 20

done