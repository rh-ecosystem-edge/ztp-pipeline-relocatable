#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

if ./verify.sh; then

    # Load common vars
    source ${WORKDIR}/shared-utils/common.sh

    echo ">>>> Deploy manifests to install MCE"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 01-namespace.yml
    oc apply -f 02-operatorgroup.yml
    oc apply -f 03-subscription.yml
    check_resource "deployment" "multicluster-engine-operator" "Available" "multicluster-engine" "${KUBECONFIG_HUB}"

    echo ">>>> Deploy MCE cr manifest"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 04-mce-cr.yml

    echo ">>>> Wait until MCE ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    check_resource "deployment" "infrastructure-operator" "Available" "multicluster-engine" "${KUBECONFIG_HUB}"
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi
echo ">>>>EOF"
echo ">>>>>>>"
