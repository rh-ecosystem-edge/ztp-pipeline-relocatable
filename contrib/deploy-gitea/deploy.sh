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
    echo "Extract Kubeconfig for HUB Cluster"
    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################

    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/01-namespace.yml
    sleep 2
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/02-catalogsource.yml
    sleep 2
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/03-subscription.yml
    sleep 2
    check_resource "crd" "giteas.gpte.opentlc.com" "Established" "gitea" "${KUBECONFIG_HUB}"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/04-instance.yml

    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
