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
export HTTPD_NS=default

if [[ $(oc get ns | grep ${HTTPD_NS} | wc -l) -eq 0 ]]; then
    #namespace or deployment/pods don't not exist. Launching the step to create it...
    exit 0
fi
if [[ $(oc get deployment -n ${HTTPD_NS} httpd -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
    #deployment or pods are not ready. Launching the step to create it...
    exit 0
else
    # everything ok don't need to do anything. Skipping
    exit 1
fi
