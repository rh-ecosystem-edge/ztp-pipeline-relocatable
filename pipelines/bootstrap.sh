#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
set -m

function create_permissions() {
    echo ">>>> Creating NS ${SPOKE_DEPLOYER_NS} and giving permissions to SA ${SPOKE_DEPLOYER_SA}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} create namespace ${SPOKE_DEPLOYER_NS} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${SPOKE_DEPLOYER_NS} create sa ${SPOKE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${SPOKE_DEPLOYER_NS} adm policy add-cluster-role-to-user cluster-admin -z ${SPOKE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    echo
}

function clone_ztp() {
    echo ">>>> Cloning Repository into your local folder"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    rm -rf ${WORKDIR}
    git clone https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable.git -b ${BRANCH} ${WORKDIR}
    echo
}

function deploy_pipeline() {
    echo ">>>> Deploying Kubeframe Pipelines and tasks"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -k ${PIPELINES_DIR}/tasks/.
}

function deploy_openshift_pipelines() {
    echo ">>>> Deploying Openshift Pipelines"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${PIPELINES_DIR}/manifests/01-subscription.yaml
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


if [[ $# -lt 1 ]];then
    echo "The first argument should be the Kubeconfig Location for your Hub Cluster"
    exit 1
fi

export BASEDIR=$(dirname "$0")
export BRANCH='tekton-pipeline'
export WORKDIR=${BASEDIR}/ztp-pipeline-relocatable
export PIPELINES_DIR=${WORKDIR}/pipelines
export SPOKE_DEPLOYER_NS=$(yq eval '.namespace' "${PIPELINES_DIR}/tasks/kustomization.yaml")
export SPOKE_DEPLOYER_SA=${SPOKE_DEPLOYER_NS}
export KUBECONFIG_HUB="${1}"

clone_ztp
create_permissions
deploy_openshift_pipelines
deploy_pipeline
