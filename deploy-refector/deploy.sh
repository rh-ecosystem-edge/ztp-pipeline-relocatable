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

    oc apply -f 01-namespace.yml

    echo ">>>> Create  reflector rolebinding"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f  02-rolebinding.yml

    echo ">>>> Deploy manifests to install OpenShift Gitops "
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    helm repo add emberstack https://emberstack.github.io/helm-charts
    helm repo update
    helm upgrade --install reflector emberstack/reflector --namespace reflector

    echo ">>>> Wait until reflector is ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    sleep 240
    while [ "${timeout}" -lt "120" ]; do
        if [[ $(oc get pod -n reflector | grep -i running | wc -l) -eq $(oc get pod -n reflector| grep -v NAME | wc -l) ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for reflector pods "
        exit 1
    fi
elif [[ $? -eq 50 ]]; then
    echo ">>>> Verify failed...Some pods are failing..." #TODO change to remove and launch again
    exit 50
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi
echo ">>>>EOF"
echo ">>>>>>>"
