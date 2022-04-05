#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# Parse args
if [ $# -eq 0 ]; then
  echo "No arguments supplied. Usage $0 <Kubeconfig file path> "
  echo "  - Ej.: ./deploy.sh /home/user/spoke1-kubeconfig"
  exit 1
fi

export SPOKE_KUBECONFIG=$1
export SPOKE=$(oc config get-clusters | sed 1d)

# Load common vars
# source ${WORKDIR}/shared-utils/common.sh

if ./verify.sh; then

    echo "Installing NFD operator for ${SPOKE}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
    sleep 2
    # echo ">>>> Waiting for subscription and crd on: ${spoke}"
    # echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    # timeout=0
    # ready=false
    # while [ "$timeout" -lt "1000" ]; do
    #     echo KUBESPOKE=${SPOKE_KUBECONFIG}
    #     if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep localvolumes.local.storage.openshift.io | wc -l) -eq 1 ]]; then
    #         ready=true
    #         break
    #     fi
    #     echo "Waiting for CRD localvolumes.local.storage.openshift.io to be created"
    #     sleep 5
    #     timeout=$((timeout + 5))
    # done
    # if [ "$ready" == "false" ]; then
    #     echo timeout waiting for CRD localvolumes.local.storage.openshift.io
    #     exit 1
    # fi

else
    echo ">>>> This step is not neccesary, everything looks ready"
fi

echo ">>>>EOF"
echo ">>>>>>>"
