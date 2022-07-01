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
    sleep 2
    oc apply -f 02-operatorgroup.yml
    sleep 2
    oc apply -f 03-subscription.yml
    sleep 40
    InstallPlan=$(oc --kubeconfig=${KUBECONFIG_HUB} get installplan -n multicluster-engine -o name)
    RESOURCE_KIND=${InstallPlan%%/*}
    RESOURCE_NAME=${InstallPlan##*/}
    check_resource "${RESOURCE_KIND}" "${RESOURCE_NAME}" "Installed" "multicluster-engine" "${KUBECONFIG_HUB}"

    echo ">>>> Deploy MCE cr manifest"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 04-mce-cr.yml
    # We need to give some time to MCE Operator to create the proper resources
    sleep 60

    echo ">>>> Wait until MCE ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    for dep in $(oc --kubeconfig=${KUBECONFIG_HUB} get deployment -n multicluster-engine -o name); do
        RESOURCE_KIND=${dep%%/*}
        RESOURCE_NAME=${dep##*/}
        check_resource "${RESOURCE_KIND}" "${RESOURCE_NAME}" "Available" "multicluster-engine" "${KUBECONFIG_HUB}"
    done
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi
echo ">>>>EOF"
echo ">>>>>>>"
