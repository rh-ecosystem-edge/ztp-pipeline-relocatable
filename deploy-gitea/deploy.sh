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

    echo ">>>> Waiting for subscription and crd"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        echo KUBESPOKE=${SPOKE_KUBECONFIG}
        if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep giteas.gpte.opentlc.com | wc -l) -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Waiting for CRD giteas.gpte.opentlc.com  to be created"
        sleep 5
        timeout=$((timeout + 5))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for CRD giteas.gpte.opentlc.com"
        exit 1
    fi


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
