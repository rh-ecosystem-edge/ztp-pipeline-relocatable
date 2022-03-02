#!/usr/bin/env bash

set -o pipefail
set -o nounset
#set -o errexit
set -m

function get_tkn() {
    URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/pipeline/latest/tkn-linux-amd64-0.21.0.tar.gz"
    BIN_FOLDER="${HOME}/bin"

    if ! (command -v tkn &>/dev/null); then
        echo ">>>> Downloading TKN Client into: ${BIN_FOLDER}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        mkdir -p ${BIN_FOLDER}
        wget ${URL} -O "${BIN_FOLDER}/tkn.tar.gz"
        tar xvzf "${BIN_FOLDER}/tkn.tar.gz" -C "${BIN_FOLDER}"
        chmod 755 ${BIN_FOLDER}/tkn
        rm -rf "${BIN_FOLDER}/LICENSE"
    else
        echo ">>>> Binary tkn already installed!"
    fi
}

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
    while [ "$timeout" -lt "240" ]; do
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
    echo ">>>> Creating NS ${SPOKE_DEPLOYER_NS} and giving permissions to SA ${SPOKE_DEPLOYER_SA}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} create namespace ${SPOKE_DEPLOYER_NS} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${SPOKE_DEPLOYER_NS} create sa ${SPOKE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} -n ${SPOKE_DEPLOYER_NS} adm policy add-scc-to-user -z anyuid ${SPOKE_DEPLOYER_SA} -o yaml --dry-run=client | oc apply -f -
    oc --kubeconfig=${KUBECONFIG_HUB} create clusterrolebinding ${SPOKE_DEPLOYER_ROLEBINDING} --clusterrole=cluster-admin --serviceaccount=spoke-deployer:pipeline -o yaml --dry-run=client | oc apply -f -
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
    echo ">>>> Deploying Kubeframe Pipelines Resources"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -k ${PIPELINES_DIR}/resources/.
}

function deploy_openshift_pipelines() {

    echo ">>>> Deploying Openshift Pipelines"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${PIPELINES_DIR}/manifests/01-subscription.yaml
    sleep 30

    check_resource "deployment" "openshift-pipelines-operator" "Available" "openshift-operators"
    check_resource "deployment" "tekton-operator-webhook" "Available" "openshift-operators"

    declare -a StringArray=("clustertasks.tekton.dev" "conditions.tekton.dev" "pipelineresources.tekton.dev" "pipelineruns.tekton.dev" "pipelines.tekton.dev" "runs.tekton.dev" "taskruns.tekton.dev" "tasks.tekton.dev" "tektonaddons.operator.tekton.dev" "tektonconfigs.operator.tekton.dev" "tektoninstallersets.operator.tekton.dev" "tektonpipelines.operator.tekton.dev" "tektontriggers.operator.tekton.dev")
    for crd in ${StringArray[@]}
    do
        check_resource "crd" "${crd}" "Established" "openshift-operators"
    done

}

function clean_openshift_pipelines() {

    echo ">>>> Cleaning Openshift Pipelines and their components"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc delete subscriptions.operators.coreos.com -n openshift-operators openshift-pipelines-operator-rh
    oc delete csv -n openshift-operators $(oc get csv -n openshift-operators --no-headers | grep openshift-pipelines-operator | cut -f1 -d\ )
    oc delete ns ${SPOKE_DEPLOYER_NS} 
    oc delete mutatingwebhookconfigurations webhook.operator.tekton.dev webhook.pipeline.tekton.dev webhook.triggers.tekton.dev
    oc delete validatingwebhookconfigurations validation.webhook.operator.tekton.dev validation.webhook.pipeline.tekton.dev validation.webhook.triggers.tekton.dev
    oc delete apiservices v1alpha1.operator.tekton.dev v1alpha1.tekton.dev v1alpha1.triggers.tekton.dev v1beta1.tekton.dev v1beta1.triggers.tekton.dev

    for crd in $(oc get crd | grep tekton | cut -f1 -d\ )
    do 
        oc delete crd $crd --grace-period=10 --force
        if [[ ${?} != 0 ]];then
            oc patch crd $crd -p '{"metadata":{"finalizers":null}}' --type merge
        fi
    done

}

export BASEDIR=$(dirname "$0")
export BRANCH=${1:-main}
export WORKDIR=${BASEDIR}/ztp-pipeline-relocatable
export KUBECONFIG_HUB="${KUBECONFIG}"
export PIPELINES_DIR=${WORKDIR}/pipelines

get_tkn
clone_ztp
export SPOKE_DEPLOYER_NS=$(yq eval '.namespace' "${PIPELINES_DIR}/resources/kustomization.yaml")
export SPOKE_DEPLOYER_SA=${SPOKE_DEPLOYER_NS}
export SPOKE_DEPLOYER_ROLEBINDING=ztp-cluster-admin

if [[ ${#} -ge 2 ]];then
        if [[ ${2} == 'clean' ]]; then
            clean_openshift_pipelines
        echo "Done!"
        exit 0
        fi
fi

if [[ -z "${KUBECONFIG}" ]]; then
    echo "KUBECONFIG var is empty"
    exit 1
fi

create_permissions
deploy_openshift_pipelines
deploy_pipeline
