#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n ${spoke} secret/${spoke}-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0
for spoke in ${ALLSPOKES}; do
    echo "Extract Kubeconfig for ${spoke}"
    extract_kubeconfig ${spoke}
    echo ">>>> Check if spoke ${spoke} require gpu-operator."
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    
    if [[ $(yq eval ".spokes[${index}].${spoke}.contrib|keys" ${SPOKES_FILE} | grep gpu-operator  | wc -l) -eq 0 ]]; then
        echo ">>>> Spoke ${spoke} does not require gpu-operator."
        exit 0
    fi

    check_resource "crd" "clusterpolicies.nvidia.com" "Established" "nvidia-gpu-operator"

    if [[ $? -eq 0 ]]; then
        echo ">>>> Spoke ${spoke} already have gpu-operator."
        exit 0
    fi
    let index++
done
exit 1
