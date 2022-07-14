#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

if [[ $(oc get pod -n multicluster-engine | grep assisted-service | grep 2/2 | wc -l) -ne 1 || $(oc get pod -n multicluster-engine | grep assisted-image | grep 1/1 | wc -l) -ne 1 ]]; then
    #multicluster-engine assisted-pod does not exist. Launching the step to create it...
    exit 0
else
    #everything is fine (two pods are running, asssited-service 2/2  and assisted-image-service 1/1)
    exit 1
fi

echo ">>>>EOF"
echo ">>>>>>>"
