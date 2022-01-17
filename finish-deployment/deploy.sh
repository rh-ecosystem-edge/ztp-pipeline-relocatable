#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

function dettach_cluster() {
    cluster=${1}
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${cluster}
}

source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Dettaching clusters"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
    echo ">>>> Detaching Spoke cluster: ${cluster}"
    #dettach_cluster ${spoke}
done
