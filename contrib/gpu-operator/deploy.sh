#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function get_config() {

    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SPOKES_FILE> <SPOKE_NAME> <SPOKE_INDEX>"
        exit 1
    fi
    spokes_file=${1}
    spoke_name=${2}
    index=${3}

    export CHANGEME_VERSION=$(yq eval ".spokes[${index}].${spoke_name}.contrib.gpu-operator.version" ${spokes_file})
}

function deploy_gpu() {
    if ! ./verify.sh; then

        echo "Installing NFD operator for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
        sleep 2

        check_resource "crd" "nodefeaturediscoveries.nfd.openshift.io" "Established" "openshift-nfd" "${SPOKE_KUBECONFIG}"

        echo "Installing GPU operator for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-gpu-namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-gpu-operator-group.yaml
        sleep 2
        envsubst <manifests/03-gpu-subscription.yaml | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
        sleep 2

        check_resource "crd" "clusterpolicies.nvidia.com" "Established" "nvidia-gpu-operator" "${SPOKE_KUBECONFIG}"

        echo "Adding GPU node labels with NFD for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/04-nfd-gpu-feature.yaml
        sleep 2

        echo "Adding GPU Cluster Policy for ${spoke}"
        envsubst <manifests/05-gpu-cluster-policy.yaml | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
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
    get_config ${SPOKES_FILE} ${spoke} ${index}
    deploy_gpu ${spoke}
    index=$((index + 1))
    echo ">> GPU Operator Deployment done in: ${spoke}"
done
