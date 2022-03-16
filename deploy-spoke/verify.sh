#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function check_aci() {
    cluster=${1}
    wait_time=${2}
    desired_status=${3}
    timeout=0
    ready=false

    while [ "${timeout}" -lt "${wait_time}" ]; do
        # Check state
        if [[ $(oc --kubeconfig=${KUBECONFIG_HUB} get aci -n ${cluster} ${cluster} -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}') == "${desired_status}" ]]; then
            ready=true
            break
        fi
        echo ">> Waiting for ACI"
        echo "Spoke: ${cluster}"
        echo "Current: $(oc --kubeconfig=${KUBECONFIG_HUB} get aci -n ${cluster} ${cluster} -o jsonpath='{.status.debugInfo.stateInfo}')"
        echo "Desired State: Cluster is Installed"
        echo
        timeout=$((timeout + 30))
        sleep 30
    done

    if [ "${ready}" == "false" ]; then
        echo "Timeout waiting for AgentClusterInstall ${cluster} on condition .status.conditions.Completed"
        echo "Expected: ${desired_status} Current: $(oc --kubeconfig=${KUBECONFIG_HUB} get aci -n ${cluster} -o jsonpath='{.status.conditions[?(@.type=="Completed")].status}')"
        exit 1
    else
        echo "AgentClusterInstall for ${cluster} verified"
    fi
}

function check_bmhs() {
    cluster=${1}
    wait_time=${2}
    timeout=0
    ready=false

    while [ "${timeout}" -lt "${wait_time}" ]; do
        RCBMH=$(oc --kubeconfig=${KUBECONFIG_HUB} get bmh -n ${cluster} -o jsonpath='{.items[*].status.provisioning.state}')
        # Check state
        if [[ $(echo ${RCBMH} | grep provisioned | wc -w) -eq 3 || $(echo ${RCBMH} | grep provisioned | wc -w) -eq 4 ]]; then
            ready=true
            break
        fi
        echo ">> Waiting for BMH on spoke for each cluster node: $(oc get bmh -n ${cluster} -o jsonpath='{.items[*].status.provisioning.state}')"
        echo 'Desired State: provisioned'
        echo

        timeout=$((timeout + 30))
        sleep 30
    done

    if [ "${ready}" == "false" ]; then
        echo "timeout waiting for BMH to be provisioned"
        exit 1
    else
        echo "BMH's for ${cluster} verified"
    fi
}

wait_time=${1}

if [[ $# -lt 1 ]]; then
    echo "Usage :"
    echo "  $0 <Wait Time>"
    exit 1
fi

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for SPOKE in ${ALLSPOKES}; do
    echo ">>>> Starting the validation until finish the installation"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    check_bmhs "${SPOKE}" "${wait_time}"
    check_aci "${SPOKE}" "${wait_time}" "True"
    echo ">>>>EOF"
    echo ">>>>>>>"
done
exit 0
