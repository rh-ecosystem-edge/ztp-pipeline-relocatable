#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
set -m

source ${WORKDIR}/shared-utils/common.sh


function deploy_pipeline() {
    echo ">>>> Deploying Kubeframe Pipelines and tasks"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -k .
}

function deploy_openshift_pipelines() {
    echo ">>>> Deploy Openshift Pipelines"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${WORKDIR}/manifests/01-subscription.yaml
    sleep 5
    
    echo ">>>> Waiting for: Openshift Pipelines"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        if [[ $(oc get --kubeconfig=${KUBECONFIG_HUB} pod -n openshift-operators | grep -i running | wc -l) -eq $(oc --kubeconfig=${KUBECONFIG_HUB} get pod -n openshift-operators --no-headers | grep -v Completed | wc -l) ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 5))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for Openshift Pipelines pods..."
        exit 1
    fi
}


deploy_openshift_pipelines
deploy_pipeline
