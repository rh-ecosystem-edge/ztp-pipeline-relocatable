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
    check_resource "deployment" "httpd" "Available" "${HTTPD_NS}" "${KUBECONFIG_HUB}"

    echo ">>>> Pre-load the images rhcos to be available"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    RHCOS_ISO="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest-${OC_OCP_VERSION_MIN}/rhcos-live.x86_64.iso"
    RHCOS_ROOTFS="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest-${OC_OCP_VERSION_MIN}/rhcos-live-rootfs.x86_64.img"
    RHCOS_SHA="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest-${OC_OCP_VERSION_MIN}/sha256sum.txt"
    BASE_ISO=$(basename $RHCOS_ISO)
    BASE_ROOTFS=$(basename $RHCOS_ROOTFS)
    BASE_SHA=$(basename $RHCOS_SHA)
    podname=$(oc get pod -n ${HTTPD_NS} | grep httpd | awk '{print $1}')

    oc exec -n ${HTTPD_NS} ${podname} -- mkdir -p /var/www/html/"${OC_OCP_VERSION_MIN}"
    oc exec -n ${HTTPD_NS} ${podname} -- curl -Lk ${RHCOS_ISO} -o /var/www/html/"${OC_OCP_VERSION_MIN}"/"${BASE_ISO}"
    oc exec -n ${HTTPD_NS} ${podname} -- curl -Lk ${RHCOS_ROOTFS} -o /var/www/html/"${OC_OCP_VERSION_MIN}"/"${BASE_ROOTFS}"

    echo "INFO: verifying Downloaded files"
    oc exec -n ${HTTPD_NS} ${podname} -- curl -Lk  ${RHCOS_SHA} -o /var/www/html/"${OC_OCP_VERSION_MIN}"/"${BASE_SHA"§
    oc exec -n ${HTTPD_NS} ${podname} -- sha256sum --check sha256sum.txt  --ignore-missing  
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi

echo ">>>>EOF"
echo ">>>>>>>"
