#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig   
export KUBECONFIG="$OC_KUBECONFIG_PATH"

echo ">>>> Create httpd server manifest"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

domain=$(grep server "$KUBECONFIG" | awk '{print $2}' | cut -d '.' -f 2- | cut -d ':' -f 1)
sed -i "s/CHANGEDOMAIN/apps.$domain/g" http-server.yml

oc create -f http-server.yml; sleep 20


echo ">>>> Pre-load the images rhcos to be available"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

export RHCOS_VERSION=$(openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["release"]')
export RHCOS_ISO_URI=$(openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["iso"]["disk"]["location"]')
export RHCOS_ROOT_FS=$(openshift-baremetal-install coreos print-stream-json | jq -r '.["architectures"]["x86_64"]["artifacts"]["metal"]["formats"]["pxe"]["rootfs"]["location"]')
export OCP_RELEASE_DOWN_PATH=/usr/share/nginx/html/$OCP_RELEASE
echo "RHCOS_VERSION: $RHCOS_VERSION"
echo "RHCOS_ISO_URI: $RHCOS_ISO_URI"
echo "RHCOS_ROOT_FS: $RHCOS_ROOT_FS"
if [[ ! -d ${OCP_RELEASE_DOWN_PATH} ]]; then
	echo "----> Downloading RHCOS resources to ${OCP_RELEASE_DOWN_PATH}"
	sudo mkdir -p ${OCP_RELEASE_DOWN_PATH}
	echo "--> Downloading RHCOS resources: RHCOS QEMU Image"
	sudo curl -s -L -o ${OCP_RELEASE_DOWN_PATH}/$(echo $RHCOS_QEMU_URI | xargs basename) ${RHCOS_QEMU_URI}
	echo "--> Downloading RHCOS resources: RHCOS Openstack Image"
	sudo curl -s -L -o ${OCP_RELEASE_DOWN_PATH}/$(echo $RHCOS_OPENSTACK_URI | xargs basename) ${RHCOS_OPENSTACK_URI}
	echo "--> Downloading RHCOS resources: RHCOS ISO"
	sudo curl -s -L -o ${OCP_RELEASE_DOWN_PATH}/$(echo $RHCOS_ISO_URI | xargs basename) ${RHCOS_ISO_URI}
	echo "--> Downloading RHCOS resources: RHCOS RootFS"
	sudo curl -s -L -o ${OCP_RELEASE_DOWN_PATH}/$(echo $RHCOS_ROOT_FS | xargs basename) ${RHCOS_ROOT_FS}
else
	echo "The folder already exist, so delete it if you want to re-download the RHCOS resources"
fi

echo ">>>>EOF"
echo ">>>>>>>"


