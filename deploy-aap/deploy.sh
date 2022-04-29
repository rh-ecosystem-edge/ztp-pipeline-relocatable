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
    sleep 2

    echo ">>>> Deploy manifests to install AAP"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 02-operatorgroup.yml
    sleep 10
    oc apply -f 03-subscription.yml

    OC_COMMAND=$(oc get csv -n ansible-automation-platform | grep "Ansible Automation Platform" | grep Succeeded | wc -l)
    timeout=0
    while [ "${timeout}" -lt "120" ]; do
        if [[ ${OC_COMMAND} -eq 1 ]]; then
            ready=true
            break
        fi
        echo "Wait for Ansible Automation Platform"
        sleep 5
        timeout=$((timeout + 1))
        OC_COMMAND=$(oc get csv -n ansible-automation-platform | grep "Ansible Automation Platform" | grep Succeeded | wc -l)
    done


    echo ">>>> Deploy AAP instance"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc apply -f 04-instance.yml
   

    echo ">>>> Wait until acm ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    sleep 240
    while [ "${timeout}" -lt "120" ]; do
        if [[ $(oc get pod -n ansible-automation-platform | grep  ac-  | grep -i running | wc -l) -eq $(oc get pod -n ansible-automation-platform | grep  ac-  | wc -l) ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for ansible-automation-platform  pods "
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