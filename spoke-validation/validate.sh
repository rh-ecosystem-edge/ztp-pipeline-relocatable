#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars

echo ">>>> Download jq, oc, kubectl and set bash completion"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 >/usr/bin/jq
chmod u+x /usr/bin/jq

if [ ! -d "/root/bin" ]; then
	mkdir -p /root/bin
	export PATH="$PATH:/root/bin"
fi

cd /root/bin
curl -k -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz >oc.tar.gz
tar zxf oc.tar.gz
rm -rf oc.tar.gz
mv oc /usr/bin
chmod +x /usr/bin/oc

cd /root/bin
curl -k -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz >opm.tar.gz
tar zxf opm.tar.gz
rm -rf opm.tar.gz
mv opm /usr/bin
chmod +x /usr/bin/opm

curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl
chmod u+x /usr/bin/kubectl

oc completion bash >>/etc/bash_completion.d/oc_completion

echo ">>>> Verify podman command"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if ! command -v podman &>/dev/null; then
	echo "Error: podman command not found. Installing..."
	yum install -y podman
fi

echo ">>>> Verify yq command"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if ! command -v yq &>/dev/null; then
	echo "Error: yq command not found. Installing..."
	wget https://github.com/mikefarah/yq/releases/download/v4.14.2/yq_linux_amd64 -O /usr/bin/yq &&
		chmod +x /usr/bin/yq
fi

echo ">>>> Loading the Kubeconfig file"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if [ ! -f "$KUBECONFIG" ]; then
	echo "Error: Kubeconfig file not found in the path passed in github actions"
	exit 1
fi

echo ">>>> Verify ocp server version $OC_OCP_VERSION"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

if [[ $(oc version | grep -i server | grep $OC_OCP_VERSION | wc -l) -ne 1 ]]; then
	echo "Error: OCP version not supported"
	exit 2
fi

echo ">>>> Verify oc get nodes"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
if [[ $(oc get nodes | grep -i ready | wc -l) -ne 1 ]] && [[ $(oc get nodes | grep -i ready | wc -l) -ne 3 ]]; then
	echo "Error: Nodes are not ready"
	exit 3
fi

echo ">>>> Verify the cluster operator ready"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if [[ $(oc get co | awk '{print $3}' | grep -i true | wc -l) -ne $(($(oc get co | wc -l) - 1)) ]]; then
	echo "Error: some cluster operators are not ready"
	exit 4
fi

echo ">>>> Verify the metal3 pods ready"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if [[ $(oc get pod -n openshift-machine-api | wc -l) -lt 1 ]]; then
	echo "Error: metal3 pods are not available to use ztp"
	exit 5
fi

echo ">>>> Verify the PV available"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
if [[ $(oc get pv | wc -l) -lt 3 ]]; then
	#TODO verify the PV size  and if does not exists, create it from disk
	echo "Error: Persisten volumes not available in the hub"
	exit 6
fi

echo ">>>> EOF"
echo ">>>>>>>>"
exit 0

oc get bmh
NAME STATE CONSUMER ONLINE ERROR
kubeframe-master-0 provisioned true
kubeframe-master-1 provisioned true
kubeframe-master-2 provisioned true

oc get agent
NAME CLUSTER APPROVED ROLE STAGE
11e619aa-20a3-4155-9e14-502502fd1fdb spoke1-cluster true auto-assign
8217b7cc-a06e-4090-841d-bb1f48215d41 spoke1-cluster true auto-assign
b679cca3-1aad-4f0d-bdbb-4a4fb19857e9 spoke1-cluster true auto-assign

insufficient

192.168.7.243 api.spoke1-cluster.kubeframe.local api-int.spoke1-cluster.kubeframe.local
192.168.7.242 assisted-service-assisted-installer.apps.spoke1-cluster.kubeframe.local assisted-service-open-cluster-management.spoke1-cluster.kubeframe.local console-openshift-console.apps.spoke1-cluster.kubeframe.local multicloud-console.apps.spoke1-cluster.kubeframe.local httpd-server.apps.spoke1-cluster.kubeframe.local oauth-openshift.apps.spoke1-cluster.kubeframe.local prometheus-k8s-openshift-monitoring.apps.spoke1-cluster.kubeframe.local
