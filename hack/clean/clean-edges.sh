#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

for EDGE in ${ALLEDGECLUSTERS}; do
    echo ">>>> Cleaning the deployed Edge-clusters clusters"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo Edge-cluster: ${EDGE}
    oc --kubeconfig=${KUBECONFIG_HUB} delete managedcluster ${EDGE}
    oc --kubeconfig=${KUBECONFIG_HUB} delete ns ${EDGE}
    sleep 60
    kcli delete vm ${EDGE}-m0 ${EDGE}-m1 ${EDGE}-m2 ${EDGE}-w0 -y
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
done
exit 0
