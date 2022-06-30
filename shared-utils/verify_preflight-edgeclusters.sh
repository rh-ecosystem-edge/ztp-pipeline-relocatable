#!/usr/bin/env bash

set -o pipefail
set -o errexit
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
debug_status starting

echo ">>>> Verify the DNS requirements"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
for edgecluster in ${ALLEDGECLUSTERS}; do
    grab_api_ingress ${edgecluster}
    echo ">>>> EDGE_API_IP: ${EDGE_API_IP}"
    echo ">>>> EDGE_API_INGRESS: ${EDGE_INGRESS_IP}"
    echo ">>>> HUB_BASEDOMAIN: ${HUB_BASEDOMAIN}"
    if [[ ${EDGE_API_IP} == "" || ${EDGE_INGRESS_IP} == "" || ${HUB_BASEDOMAIN} == "" ]]; then
        echo "Error: DNS Entry are not available for edgecluster ${edgecluster}"
        exit 1
    fi
done

echo ">>>> Verify the Mandatory root_disk requirements"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
index=0
for edgecluster in ${ALLEDGECLUSTERS}; do
    for master in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l) - 1)))); do
        root_disk=$(yq e ".edgeclusters[${index}].[].master${master}.root_disk" $EDGECLUSTERS_FILE)
        if [[ ${root_disk} == "" ]] || [[ ${root_disk} == "null" ]]; then
            echo "Error: root_disk is not defined for master ${master} at edgecluster ${edgecluster}"
            exit 1
        fi
    done

    for worker in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep worker | wc -l) - 1)))); do
        root_disk=$(yq e ".edgeclusters.[${index}].[].worker${worker}.root_disk" $EDGECLUSTERS_FILE)
        if [[ ${root_disk} == "" ]] || [[ ${root_disk} == "null" ]]; then
            echo "Error: root_disk is not defined for worker ${worker} at edgecluster ${edgecluster}"
            exit 1
        fi
    done
    index=$((index + 1))
done

debug_status ending
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"
exit 0
