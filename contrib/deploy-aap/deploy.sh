#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ! ./verify.sh; then

    echo ">>>> Deploy manifests to create template namespace "
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################

    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/01-namespace.yml
    sleep 2
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/02-operatorgroup.yml
    sleep 2
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/03-subscription.yml
    sleep 2
    check_resource "crd" "automationhubs.automationhub.ansible.com" "Established" "ansible-automation-platform" "${KUBECONFIG_HUB}"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/04-instance.yml

    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
