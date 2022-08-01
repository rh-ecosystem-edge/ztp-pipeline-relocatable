#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ! ./verify.sh; then

    echo ">>>> Deploy manifests to create template namespace in: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Extract Kubeconfig for ${edgecluster}"
    extract_kubeconfig ${edgecluster}
    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################

    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-namespace.yml
    sleep 2
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-operatorgroup.yml
    sleep 2
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-subscription.yml
    sleep 2
    check_resource "crd" "giteas.gpte.opentlc.com" "Established" "gitea" "${EDGE_KUBECONFIG}"
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/04-instance.yml

    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
