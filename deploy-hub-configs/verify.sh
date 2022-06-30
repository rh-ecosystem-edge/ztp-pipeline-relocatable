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
debug_status starting

if [[ $(oc get pod -n open-cluster-management | grep assisted-service | grep 2/2 | wc -l) -ne 1 || $(oc get pod -n open-cluster-management | grep assisted-image | grep 1/1 | wc -l) -ne 1 ]]; then
    #Open-Cluster-Management assisted-pod does not exist. Launching the step to create it...
    exit 0
else
    #everything is fine (two pods are running, asssited-service 2/2  and assisted-image-service 1/1)
    exit 1
fi

debug_status ended
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")" 
