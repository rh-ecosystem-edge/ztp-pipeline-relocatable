#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function validate_condition() {
    timeout=0
    ready=false
    while [ "${timeout}" -lt "${wait_time}" ]; do
        test "$(oc get -n ${SPOKE} ${1} -o jsonpath=${2})" == "${states_machine[${1}, ${2}]}" && ready=true && break
        echo "Waiting for spoke cluster ${SPOKE} to be deployed" # TODO add more info about the process adding new field to matrix with descrliption
        sleep 60
        timeout=$((timeout + 1))
    done

    if [ "${ready}" == "false" ]; then
        echo "timeout waiting for spoke cluster ${SPOKE} to be deployed"
        exit 1
    else
        echo "Condition ${1} verified"

    fi
}

## main function
##

if [ "${#}" -ne 1 ]; then
    echo "Usage: ${0} <spoke>"
    exit 1
fi

## variables
## #########
SPOKE="${1}"
wait_time=90                                                                                           # wait until 90 min
declare -A states_machine                                                                              #TODO add more steps to validate agent, agentclusterinstall and so on
states_machine['bmh', '{.items[*].status.errorCount}']='0 0 0'                                         # bmh's without errors
states_machine['bmh', '{.items[*].status.provisioning.state}']='provisioned provisioned provisioned'   # bmh's state provisioned
states_machine['agent', '{.items[*].spec.approved}']='true true true'                                  # agent's state approved
states_machine['agentclusterinstall', '{.items[*].status.debugInfo.stateInfo}']='Cluster is installed' # agent cluster install state

echo ">>>> Starting the validation until finish the installation"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

validate_condition "bmh" "{.items[*].status.errorCount}"
validate_condition "bmh" "{.items[*].status.provisioning.state}"
validate_condition "agent" "{.items[*].spec.approved}"
validate_condition "agentclusterinstall" "{.items[*].status.debugInfo.stateInfo}"

echo ">>>>EOF"
echo ">>>>>>>"
exit 0
