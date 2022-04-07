#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function wait_for_crd() {
    SPOKE_KUBECONFIG=${1}
    SPOKE_NAME=${2}
    CRD=${3}

    echo ">>>> Waiting for subscription and crd on: ${SPOKE_NAME}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false

    while [ "$timeout" -lt "1000" ]; do
        echo KUBESPOKE=${SPOKE_KUBECONFIG}
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep ${CRD} | wc -l) -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Waiting for CRD ${CRD} to be created"
        sleep 5
        timeout=$((timeout + 5))
    done
    if [ "$ready" == "false" ]; then
        echo timeout waiting for CRD ${CRD}
        exit 1
    fi
}

# Parse args
if [ $# -eq 0 ]; then
  echo "No arguments supplied. Usage $0 <Kubeconfig file path> "
  echo "  e.g.: ./deploy.sh /home/user/spoke1-kubeconfig"
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
    
    wait_for_crd ${SPOKE_KUBECONFIG} ${SPOKE} "nodefeaturediscoveries.nfd.openshift.io"

    echo "Installing GPU operator for ${SPOKE}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-gpu-namespace.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-gpu-operator-group.yaml
    sleep 2
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-gpu-subscription.yaml
    sleep 2

    wait_for_crd ${SPOKE_KUBECONFIG} ${SPOKE} "clusterpolicies.nvidia.com"

    echo "Adding GPU node labels with NFD for ${SPOKE}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/04-nfd-gpu-feature.yaml
    sleep 2

    echo "Adding GPU Cluster Policy for ${SPOKE}"
    oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/05-gpu-cluster-policy.yaml
    sleep 2
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi

echo ">>>>EOF"
echo ">>>>>>>"
