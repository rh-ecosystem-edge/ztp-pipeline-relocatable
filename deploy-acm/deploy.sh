#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig 

echo ">>>> Modify files to replace with pipeline info gathered"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sed -i "s/CHANGEME/$OC_ACM_VERSION/g" 03-subscription.yml

echo ">>>> Deploy manifests to install ACM $OC_ACM_VERSION"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create -f 01-namespace.yml; sleep 2
oc create -f 02-operatorgroup.yml; sleep 2
oc create -f 03-subscription.yml; sleep 60

echo ">>>> Deploy ACM cr manifest"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create -f 04-acm-cr.yml; sleep 60


echo ">>>> Wait until acm ready"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
timeout=0
ready=false
sleep 240
while [ "$timeout" -lt "60" ] ; do
  if [[ $(oc get pod -n open-cluster-management | grep -i running | wc -l) -eq  $(oc get pod -n open-cluster-management | grep -v NAME | wc -l) ]]; then
    ready=true
    break
  fi
  sleep 5
  timeout=$(($timeout + 5))
done
if [ "$ready" == "false" ] ; then
 echo "timeout waiting for ACM pods "
 exit 1
fi

echo ">>>> Deploy AI over ACM"
echo ">>>>>>>>>>>>>>>>>>>>>>>"

sed -i "s%TAG_OCP_IMAGE_RELEASE%$OC_OCP_VERSION%g" 05-cluster_imageset.yml
sec -i "s/CHANGEME/$OC_RHCOS_RELEASE/g" 07-agent-service-config.yml


#
#echo ">>>> Wait for ACM and AI deployed successfully"
#echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
#while [[ $(oc get pod -n open-cluster-management | grep assisted | wc -l) -eq 0 ]]; do
#    echo "Waiting for Assisted installer to be ready..."
#    sleep 5
#done
#../$SHARED_DIR/wait_for_deployment.sh -t 1000 -n open-cluster-management assisted-service
#

echo ">>>>EOF"
echo ">>>>>>>"


