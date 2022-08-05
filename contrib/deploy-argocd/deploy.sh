#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

if ./verify.sh; then
    # Load common vars
    source ${WORKDIR}/shared-utils/common.sh

    echo ">>>> Deploy manifests to create template namespace in: HUB Cluster"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Extract Kubeconfig for HUB Cluster}"

    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################

    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-namespace.yml
    sleep 2
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-subscription.yml
    sleep 2
    check_resource "crd" "gitopsservices.pipelines.openshift.io" "Established" "argocd" "${EDGE_KUBECONFIG}"
    oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-instance.yml
    sleep 2

    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
