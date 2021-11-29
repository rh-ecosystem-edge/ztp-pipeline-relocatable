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
source ${WORKDIR}/shared-utils/common.sh

if [[ $(oc get pod -n open-cluster-management | grep assisted | wc -l) -eq 0 ]]; then
	#Open-Cluster-Management assisted-pod does not exist. Launching the step to create it...
	exit 0
else
	#everything is fine
	exit 1
fi

echo ">>>>EOF"
echo ">>>>>>>"
