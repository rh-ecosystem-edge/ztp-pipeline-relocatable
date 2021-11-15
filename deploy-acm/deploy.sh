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

echo ">>>> Modify files to replace with pipeline info gathered"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sed -i "s/CHANGEME/$OC_ACM_VERSION/g" 03-subscription.yml

echo ">>>> Deploy manifests to install ACM $OC_ACM_VERSION"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create -f 01-namespace.yml; sleep 2
oc create -f 02-operatorgroup.yml; sleep 2
oc create -f 03-subscription.yml; sleep 2

echo ">>>> Wait for ACM to be ready"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
timeout=0
ready=false
while [ "$timeout" -lt "60" ] ; do
  oc get crd | grep -q multiclusterhubs.operator.open-cluster-management.io | && ready=true && break;
  echo "Waiting for CRD multiclusterhubs.operator.open-cluster-management.io to be created"
  sleep 1
  timeout=$(($timeout + 1))
done
if [ "$ready" == "false" ] ; then
 echo "timeout waiting for CRD multiclusterhubs.operator.open-cluster-management.io"
 exit 1
fi

echo ">>>> Deploy ACM cr manifest"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create -f 04-acm-cr.yml; sleep 2

echo ">>>> Wait for ACM and AI deployed successfully"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
../$SHARED_DIR/wait_for_deployment.sh -t 1000 -n open-cluster-management assisted-service


echo ">>>>EOF"
echo ">>>>>>>"


