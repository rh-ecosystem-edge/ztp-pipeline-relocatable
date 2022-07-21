#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m


while [[ $(oc --kubeconfig=${KUBECONFIG} get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}') == 'True' ]]
do
    # Fix failing due MCP restart api not avilable 
    echo "Waiting for MCP to restart"
    sleep 10
done


echo "Waiting for MCP to finish"
COUNTER=0
while [[ $(oc --kubeconfig=${KUBECONFIG} get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}') == 'False' ]]
do
    # Fix failing due MCP restart api not avilable 
    echo "Waiting for MCP to finish (up to 15 min)"
    if [[ ${COUNTER} -gt 90 ]]; then
        echo "ERROR: timeout waiting for MCP"
        exit 1
    fi
    sleep 10
    COUNTER=${COUNTER}+1
done

echo "Starting Pipeline"
make deploy-pipe-hub-compact
