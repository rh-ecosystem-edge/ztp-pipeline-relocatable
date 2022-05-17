#!/usr/bin/env bash

set -o pipefail
set -o nounset
#set -o errexit
set -m

function check_resource() {
    # 1 - Resource type: "deployment"
    # 2 - Resource name: "openshift-pipelines-operator"
    # 3 - Type Status: "Available"
    # 4 - Namespace: "openshift-operators"

    if [[ -z ${1} ]]; then
        echo "I need a resource to check, value passed: \"${1}\""
        exit 1
    fi

    if [[ -z ${2} ]]; then
        echo "I need a resource name to check, value passed: \"${2}\""
        exit 1
    fi

    if [[ -z ${3} ]]; then
        echo "I need a Type Status (E.G 'Available') from status.conditions json field to check, value passed: \"${3}\""
        exit 1
    fi

    if [[ -z ${4} ]]; then
        echo "I need a Namespace to check the resource into, value passed: \"${4}\""
        exit 1
    fi

    RESOURCE="${1}"
    RESOURCE_NAME="${2}"
    TYPE_STATUS="${3}"
    NAMESPACE="${4}"

    echo ">>>> Checking Resource: ${RESOURCE} with name ${RESOURCE_NAME}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        if [[ $(oc --kubeconfig=${KUBECONFIG_HUB} -n ${NAMESPACE} get ${RESOURCE} ${RESOURCE_NAME} -o jsonpath="{.status.conditions[?(@.type==\"${TYPE_STATUS}\")].status}") == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for ${RESOURCE} ${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        sleep 20
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for ${RESOURCE}-${RESOURCE_NAME} to change the status to ${TYPE_STATUS}"
        exit 1
    fi
}

function create_permissions() {
    echo ">>>> Creating NS ${EDGE_DEPLOYER_NS} and giving permissions to SA ${EDGE_DEPLOYER_SA}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} create namespace ${EDGE_DEPLOYER_NS} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${EDGE_DEPLOYER_NS} create sa ${EDGE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${EDGE_DEPLOYER_NS} adm policy add-scc-to-user -z anyuid ${EDGE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} create clusterrolebinding ${EDGE_DEPLOYER_ROLEBINDING} --clusterrole=cluster-admin --serviceaccount=edgecluster-deployer:pipeline -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${EDGE_DEPLOYER_NS} adm policy add-cluster-role-to-user cluster-admin -z ${EDGE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    echo
}

function deploy_pipeline() {
    echo ">>>> Deploying ZTPFW Pipelines Resources"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -k ${PIPELINES_DIR}/resources/.
}

function deploy_openshift_pipelines() {

    echo ">>>> Deploying OpenShift Pipelines"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${PIPELINES_DIR}/manifests/01-subscription.yaml
    sleep 15

    check_resource "deployment" "openshift-pipelines-operator" "Available" "openshift-operators"
    check_resource "deployment" "tekton-operator-webhook" "Available" "openshift-operators"

    declare -a StringArray=("clustertasks.tekton.dev" "conditions.tekton.dev" "pipelineresources.tekton.dev" "pipelineruns.tekton.dev" "pipelines.tekton.dev" "runs.tekton.dev" "taskruns.tekton.dev" "tasks.tekton.dev" "tektonaddons.operator.tekton.dev" "tektonconfigs.operator.tekton.dev" "tektoninstallersets.operator.tekton.dev" "tektonpipelines.operator.tekton.dev" "tektontriggers.operator.tekton.dev")
    for crd in ${StringArray[@]}; do
        check_resource "crd" "${crd}" "Established" "openshift-operators"
    done

}

export BASEDIR=$(dirname "$0")
export WORKDIR=${BASEDIR}/../../
export KUBECONFIG_HUB="${KUBECONFIG}"
export PIPELINES_DIR=${WORKDIR}/pipelines
export EDGE_DEPLOYER_NS=$(yq eval '.namespace' "${PIPELINES_DIR}/resources/kustomization.yaml")
export EDGE_DEPLOYER_SA=${EDGE_DEPLOYER_NS}
export EDGE_DEPLOYER_ROLEBINDING=ztp-cluster-admin

if [[ -z ${KUBECONFIG} ]]; then
    echo "KUBECONFIG var is empty"
    exit 1
fi

create_permissions
deploy_openshift_pipelines
deploy_pipeline
