#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Modify files to replace with pipeline info gathered"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
sed -i "s/CHANGEME/$OC_OCS_VERSION/g" manifests/03-OCS-Subscription.yaml

echo ">>>> Deploy manifests to install LSO"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc apply -f 01-LSO-Namespace.yaml
sleep 2
oc apply -f 02-LSO-OperatorGroup.yaml 
sleep 2
oc apply -f 03-LSO-Subscription.yaml
sleep 20

echo ">>>> Deploying LSO LocalVolume"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc apply -f 04-LSO-LocalVolume.yaml
sleep 30

echo ">>>> Waiting for: LSO PVs"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
timeout=0
ready=false
while [ "$timeout" -lt "60" ]; do
	if [[ $(oc get pv -o name | wc -l) -eq 3 ]]; then
		ready=true
		break
	fi
	sleep 5
	timeout=$((timeout + 5))
done

if [ "$ready" == "false" ]; then
	echo "timeout waiting for LSO PVs..."
	exit 1
fi

echo ">>>> Deploy manifests to install OCS $OC_OCS_VERSION"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc apply -f 01-OCS-Namespace.yaml
sleep 2
oc apply -f 02-OCS-OperatorGroup.yaml
sleep 2
oc apply -f 03-OCS-Subscription.yaml
sleep 60

echo ">>>> Labeling nodes for OCS"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
counter=0
for node in $(oc get node -o name);
do
    oc label $node cluster.ocs.openshift.io/openshift-storage=''
    oc label $node topology.rook.io/rack=rack${counter}
    let "counter+=1" 
done
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"


echo ">>>> Deploy OCS StorageCluster"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc apply -f 04-OCS-StorageCluster.yaml
sleep 60

echo ">>>> Waiting for: OCS Cluster"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
timeout=0
ready=false
sleep 240
while [ "$timeout" -lt "60" ]; do
	if [[ $(oc get pod -n openshift-storage | grep -i running | wc -l) -eq $(oc get pod -n openshift-storage | grep -v NAME | wc -l) ]]; then
		ready=true
		break
	fi
	sleep 5
	timeout=$((timeout + 5))
done
if [ "$ready" == "false" ]; then
	echo "timeout waiting for OCS pods..."
	exit 1
fi

echo ">>>>EOF"
echo ">>>>>>>"

