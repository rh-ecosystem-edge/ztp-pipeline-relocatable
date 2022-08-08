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

if [[ $(oc get ns | grep ansible-automation-platform | wc -l) -eq 0 || $(oc get AutomationController -n ansible-automation-platform --no-headers | wc -l) -eq 0 ]]; then
    #ansible-automation-platform namespace does not exist. Launching the step to create it...
    exit 0
elif [[ $(oc get pod -n ansible-automation-platform | grep -i running | wc -l) -eq $(oc get pod -n ansible-automation-platform | grep -v NAME | wc -l) ]]; then
    #All pods for AAP running...Skipping the step to create it
    exit 1
elif [[ $(oc get multiclusterhub multiclusterhub -n open-cluster-management | grep Running | wc -l) -eq 0]]; then
    #All pods for DUMMY running...Skipping the step to create it
    echo "A multiclusterhub is not running"
    exit 1
else
    #Some pods are failing...Stop pipe to solve it  #TODO this scenario we should remove the subscription and destroy everything and relaunch again
    exit 50
fi

echo ">>>>EOF"
echo ">>>>>>>"
