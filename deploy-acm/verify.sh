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

if [[ $(oc get ns | grep open-cluster-management | wc -l) -eq 0 || $(oc get multiclusterhub -n open-cluster-management --no-headers | wc -l) -eq 0 ]]; then
    #Open-Cluster-Management namespace does not exist. Launching the step to create it...
    exit 0
    debug_status ending
    echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"
elif [[ $(oc get pod -n open-cluster-management | grep -i running | wc -l) -eq $(oc get pod -n open-cluster-management | grep -v NAME | wc -l) ]]; then
    #All pods for ACM running...Skipping the step to create it
    exit 1
else
    #Some pods are failing...Stop pipe to solve it  #TODO this scenario we should remove the subscription and destroy everything and relaunch again
    exit 50
fi


