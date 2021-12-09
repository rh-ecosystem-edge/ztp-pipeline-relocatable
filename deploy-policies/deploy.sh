#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Deploying ACM policies for Kubeframe"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc create namespace ${KUBEFRAME_NS} -o yaml --dry-run=client | oc apply -f -
oc apply -k manifests/.

echo ">>>>EOF"
echo ">>>>>>>"
