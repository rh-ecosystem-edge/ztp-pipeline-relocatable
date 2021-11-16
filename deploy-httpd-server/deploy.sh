#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig   

echo ">>>> Create httpd server manifest"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

domain=$(grep server "$KUBECONFIG" | awk '{print $2}' | cut -d '.' -f 2- | cut -d ':' -f 1)
sed -i "s/CHANGEDOMAIN/apps.$domain/g" http-server.yml

oc create -f http-server.yml; sleep 20


echo ">>>> Pre-load the images rhcos to be available"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

RHCOS_ISO="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live.x86_64.iso"
RHCOS_ROOTFS="https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/pre-release/latest/rhcos-live-rootfs.x86_64.img"
curl -Lk $RHCOS_ISO > /usr/share/nginx/html/$(basename $RHCOS_ISO)
curl -Lk $RHCOS_ROOTFS > /usr/share/nginx/html/$(basename $RHCOS_ROOTFS)

echo ">>>>EOF"
echo ">>>>>>>"


