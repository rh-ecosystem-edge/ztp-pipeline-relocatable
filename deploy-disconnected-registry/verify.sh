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
source ./common.sh ${1}

function check_route_ready() {
    echo ">>>> Waiting for registry route Ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        if [[ $(oc get --kubeconfig=${1} route -n ${REGISTRY} --no-headers | wc -l) -eq 3 ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for Registry route t to be ready..."
        exit 1
    fi
}

if [[ ${1} == 'hub' ]]; then
    TG_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${1} == 'spoke' ]]; then
    TG_KUBECONFIG=${SPOKE_KUBECONFIG}
fi

if [[ $(oc --kubeconfig=${TG_KUBECONFIG} get ns | grep ${REGISTRY} | wc -l) -eq 0 || $(oc --kubeconfig=${TG_KUBECONFIG} get -n ztpfw-registry deployment ztpfw-registry -ojsonpath='{.status.availableReplicas}') -eq 0 ]]; then
    #namespace or resources does not exist. Launching the step to create it...
    exit 1
fi

if ! check_route_ready ${TG_KUBECONFIG}; then
    exit 2
fi

exit 0
