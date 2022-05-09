#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function wait_for_crd() {
    SPOKE_KUBECONFIG=${1}
    SPOKE=${2}
    CRD=${3}

    echo ">>>> Waiting for subscription and crd on: ${SPOKE}"
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

function get_config() {
    
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SPOKES_FILE> <SPOKE_NAME> <SPOKE_INDEX>"
        exit 1
    fi
    SPOKE_FILE=${1}
    SPOKE_NAME=${2}
    SPOKE_INDEX=${3}
    
    export CHANGEME_VERSION=$(yq eval ".spokes[${index}].${spoke_name}.contrib.gpu-operator.version" ${SPOKES_FILE})
}

function deploy_gpu() {
    if ./verify.sh; then

        get_config ${SPOKES_FILE} ${spoke} ${index}

        echo "Installing NFD operator for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
        sleep 2

        wait_for_crd ${SPOKE_KUBECONFIG} ${spoke} "nodefeaturediscoveries.nfd.openshift.io"

        echo "Installing GPU operator for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-gpu-namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-gpu-operator-group.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-gpu-subscription.yaml
        sleep 2

        wait_for_crd ${SPOKE_KUBECONFIG} ${spoke} "clusterpolicies.nvidia.com"

        echo "Adding GPU node labels with NFD for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/04-nfd-gpu-feature.yaml
        sleep 2

        echo "Adding GPU Cluster Policy for ${spoke}"
        envsubst <manifests/03-gpu-subscription.yaml | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
        sleep 2
    else
        echo ">>>> This step is not neccesary, everything looks ready"
    fi

    echo ">>>>EOF"
    echo ">>>>>>>"
}

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0
for spoke in ${ALLSPOKES}; do
    extract_kubeconfig_common ${spoke}
    deploy_gpu ${spoke}
    index=$((index + 1))
    echo ">> GPU Operator Deployment done in: ${spoke}"
done
