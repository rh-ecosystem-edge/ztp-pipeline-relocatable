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
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################

    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/01-namespace.yml
    helm list 
    sleep 2
    helm repo add emberstack https://emberstack.github.io/helm-charts  --namespace reflector
    sleep 2
    helm repo update --namespace reflector
    sleep 2
    helm upgrade --install reflector emberstack/reflector --namespace reflector
    sleep 2
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/02-rolebinding.yml


    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
