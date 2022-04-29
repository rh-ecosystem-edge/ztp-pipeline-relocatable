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

    echo ">>>> Deploy manifests to install Gitea "
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 02-catalogsource.yml
   
    until oc get packagemanifest gitea-operator -n openshift-marketplace; do echo "Waiting for PackageManifests...sleeping 10s..." && sleep 10; done

    oc apply -f 03-subscription.yml

    OC_COMMAND=$(oc get csv -n gitea | grep "Gitea Operator " | grep Succeeded | wc -l)
    timeout=0
    while [ "${timeout}" -lt "120" ]; do
        if [[ ${OC_COMMAND} -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Wait for Gitea Operator "
        sleep 5
        timeout=$((timeout + 1))
        OC_COMMAND=$(oc get csv -n argocd | grep "Gitea Operator " | grep Succeeded | wc -l)
    done


    echo ">>>> Deploy Gitea instance"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 04-instance.yml
   

    echo ">>>> Wait until Gitea ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    sleep 60
    while [ "${timeout}" -lt "120" ]; do
        if [[ $(oc get pod -n gitea | grep -i running | wc -l) -eq $(oc get pod -n gitea | grep -v NAME | wc -l) ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for Gitea pods "
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
