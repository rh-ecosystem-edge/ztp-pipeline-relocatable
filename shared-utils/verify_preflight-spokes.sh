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

echo ">>>> Verify the DNS requirements"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
for spoke in ${ALLSPOKES}; do
    grab_api_ingress ${spoke}
    echo ">>>> SPOKE_API_IP: ${SPOKE_API_IP}"
    echo ">>>> SPOKE_API_INGRESS: ${SPOKE_INGRESS_IP}"
    echo ">>>> HUB_BASEDOMAIN: ${HUB_BASEDOMAIN}"
    if [[ ${SPOKE_API_IP} == "" || ${SPOKE_INGRESS_IP} == "" || ${HUB_BASEDOMAIN} == "" ]]; then
        echo "Error: DNS Entry are not available for spoke ${spoke}"
        exit 7
    fi
done

echo ">>>> Verify the Mandatory root_disk requirements"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
index=0
for spoke in ${ALLSPOKES}; do
    .spokes.[0].[].master0
    for master in $(echo $(seq 0 $(($(yq eval ".spokes[${index}].[]|keys" ${SPOKES_FILE} | grep master | wc -l) - 1)))); do
        root_disk=$(yq e ".spokes[${index}].[].master${master}.root_disk" $SPOKES_FILE)
        if [[ ${root_disk} == "" ]] || [[ ${root_disk} == "null" ]]; then
            echo "Error: root_disk is not defined for master ${master} at spoke ${spoke}"
            exit 7
        fi
    done

    for worker in $(echo $(seq 0 $(($(yq eval ".spokes[${index}].[]|keys" ${SPOKES_FILE} | grep worker | wc -l) - 1)))); do
        root_disk=$(yq e ".spokes.[${index}].[].worker${worker}.root_disk" $SPOKES_FILE)
        if [[ ${root_disk} == "" ]] || [[ ${root_disk} == "null" ]]; then
            echo "Error: root_disk is not defined for worker ${worker} at spoke ${spoke}"
            exit 7
        fi
    done
    index=$((index + 1))
done

echo ">>>> EOF"
echo ">>>>>>>>"
exit 0
