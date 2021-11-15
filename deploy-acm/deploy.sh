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
oc create -f 03-subscription.yml; sleep 60

echo ">>>> Deploy ACM cr manifest"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create -f 04-acm-cr.yml; sleep 60

echo ">>>> Wait for ACM deployment finished"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
../"$SHARED_UTILS"/wait_for_pod.sh "multiclusterhub-operator" "" "open-cluster-management"

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


