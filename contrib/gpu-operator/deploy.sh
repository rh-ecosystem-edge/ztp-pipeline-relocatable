#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function get_config() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <EDGECLUSTERS_FILE> <EDGE_NAME> <EDGE_INDEX>"
        exit 1
    fi
    edgeclusters_file=${1}
    edgecluster_name=${2}
    index=${3}

    # Switch this to a boolean
    export CHANGEME_VERSION=$(yq eval ".edgeclusters[${index}].${edgecluster_name}.contrib.gpu-operator.version" ${edgeclusters_file})
}

function deploy_gpu() {
    if ! ./verify.sh; then

        echo "Installing NFD operator for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
        sleep 2

        check_resource "crd" "nodefeaturediscoveries.nfd.openshift.io" "Established" "openshift-nfd" "${EDGE_KUBECONFIG}"

        echo "Installing GPU operator for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-gpu-namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-gpu-operator-group.yaml
        sleep 2
        envsubst <manifests/03-gpu-subscription.yaml | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
        sleep 2

        check_resource "crd" "clusterpolicies.nvidia.com" "Established" "nvidia-gpu-operator" "${EDGE_KUBECONFIG}"

        echo "Adding GPU node labels with NFD for ${edgecluster}"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/04-nfd-gpu-feature.yaml
        sleep 2

        echo "Adding GPU Cluster Policy for ${edgecluster}"
        envsubst <manifests/05-gpu-cluster-policy.yaml | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
        sleep 2
    else
        echo ">>>> This step is not neccesary, everything looks ready"
    fi

    echo ">>>>EOF"
    echo ">>>>>>>"
}

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

index=0
for edgecluster in ${ALLEDGECLUSTERS}; do
    extract_kubeconfig_common ${edgecluster}
    get_config ${EDGECLUSTERS_FILE} ${edgecluster} ${index}
    deploy_gpu ${edgecluster}
    index=$((index + 1))
    echo ">> GPU Operator Deployment done in: ${edgecluster}"
done
