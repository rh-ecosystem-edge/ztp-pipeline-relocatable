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

echo ">>>> EOF"
echo ">>>>>>>>"
exit 0
