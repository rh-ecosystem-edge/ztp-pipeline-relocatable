#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

if ./verify.sh; then
	# Load common vars
	source ${WORKDIR}/shared-utils/common.sh
	export HTTPD_NS=default

	echo ">>>> Create httpd server manifest"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

	domain=$(oc get ingresscontroller -n openshift-ingress-operator ${HTTPD_NS} -o jsonpath='{.status.domain}')
	sed -i "s%CHANGEDOMAIN%${domain}%g" http-server.yml

	# TODO: create on their proper NS
	oc apply -n ${HTTPD_NS} -f http-server.yml
	../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n ${HTTPD_NS} nginx

	echo ">>>> Pre-load the images rhcos to be available"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

	RHCOS_ISO="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live.x86_64.iso"
	RHCOS_ROOTFS="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live-rootfs.x86_64.img"
	BASE_ISO=$(basename $RHCOS_ISO)
	BASE_ROOTFS=$(basename $RHCOS_ROOTFS)
	podname=$(oc get pod -n ${HTTPD_NS} | grep nginx | awk '{print $1}')

	oc exec -n ${HTTPD_NS} ${podname} -- curl -Lk ${RHCOS_ISO} -o /usr/share/nginx/html/"${BASE_ISO}"
	oc exec -n ${HTTPD_NS} ${podname} -- curl -Lk ${RHCOS_ROOTFS} -o /usr/share/nginx/html/"${BASE_ROOTFS}"
else
	echo ">>>> This step is not neccesary, everything looks ready"
fi

echo ">>>>EOF"
echo ">>>>>>>"
