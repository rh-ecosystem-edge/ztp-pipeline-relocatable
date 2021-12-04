#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

<<<<<<< HEAD
if ./verify.sh; then

	# Load common vars
	source ${WORKDIR}/shared-utils/common.sh

	echo ">>>> Modify files to replace with pipeline info gathered"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    ACM_SOURCE=$(oc get packagemanifest -n openshift-marketplace advanced-cluster-management -o jsonpath='{.status.catalogSource}')
    ACM_CHANNEL=$(oc get packagemanifest -n openshift-marketplace advanced-cluster-management -o jsonpath='{.status.defaultChannel}')
    sed -i -e "s/CHANGESOURCE/${ACM_SOURCE}/" -e "s/CHANGECHANNEL/${ACM_CHANNEL}/" 03-subscription.yml

	echo ">>>> Deploy manifests to install ACM ${OC_ACM_VERSION}"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	oc apply -f 01-namespace.yml -o yaml --dry-run=client | oc apply -f -
	sleep 2
	oc apply -f 02-operatorgroup.yml
	sleep 2
	oc apply -f 03-subscription.yml
	sleep 60

	echo ">>>> Deploy ACM cr manifest"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
	oc apply -f 04-acm-cr.yml
	sleep 60

	echo ">>>> Wait until acm ready"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
	timeout=0
	ready=false
	sleep 240
	while [ "${timeout}" -lt "60" ]; do
		if [[ $(oc get pod -n open-cluster-management | grep -i running | wc -l) -eq $(oc get pod -n open-cluster-management | grep -v NAME | wc -l) ]]; then
			ready=true
			break
		fi
		sleep 5
		timeout=$((timeout + 5))
	done
	if [ "$ready" == "false" ]; then
		echo "timeout waiting for ACM pods "
		exit 1
	fi
elif [[ $? -eq 50 ]]; then
	echo ">>>> Verify failed...Some pods are failing..." #TODO change to remove and launch again
	exit 50
else
	echo ">>>> This step is not neccesary, everything looks ready"
fi
echo ">>>>EOF"
echo ">>>>>>>"
