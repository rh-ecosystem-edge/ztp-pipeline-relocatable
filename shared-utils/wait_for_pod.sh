#!/usr/bin/env bash
# Waits for a pod to complete.
#
# Includes a two-step approach:
#
# 1. Wait for the observed generation to match the specified one $1.
# 2. you could ignore one $2.
# 3. Namespace in param $3
#
#
set -o errexit
set -o pipefail
set -o nounset
set -m

FOUND=1
MINUTE=0
podName=$1
ignore=$2
TARGET_NAMESPACE=$3
running="\([0-9]\+\)\/\1"
echo "Waiting for the pod: $podName"
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 4min, should only take about 20-30s
    if [ $MINUTE -gt 240 ]; then
        echo "Timeout waiting for the ${podName}. Exiting."
        echo "List of current pods:"
        oc -n "${TARGET_NAMESPACE}" get pods
        echo
        echo "You should see ${podName}"
        exit 1
    fi
    if [ "$ignore" == "" ]; then
        operatorPod=$(oc -n "${TARGET_NAMESPACE}" get pods | grep "${podName}")
    else
        operatorPod=$(oc -n "${TARGET_NAMESPACE}" get pods | grep "${podName}" | grep -v "${ignore}")
    fi
    if [[ $(echo $operatorPod | grep  "${running}") ]]; then
        echo "* ${podName} is running"
        break
    elif [ "$operatorPod" == "" ]; then
        operatorPod="Waiting"
    fi
    echo "* STATUS: $operatorPod"
    sleep 3
    (( MINUTE = MINUTE + 3 ))
done
