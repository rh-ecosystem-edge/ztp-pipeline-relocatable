#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function check_resource() {
    # 1 - Resource type: "deployment"
    # 2 - Resource name: "openshift-pipelines-operator"
    # 3 - Type Status: "Available"
    # 4 - Namespace: "openshift-operators"
    # 5 - Kubeconfig: ""

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

    if [[ -z ${5} ]]; then
        echo "I need a Kubeconfig, value passed: \"${5}\""
        exit 1
    fi


    RESOURCE="${1}"
    RESOURCE_NAME="${2}"
    TYPE_STATUS="${3}"
    NAMESPACE="${4}"
    KUBE="${5}"

    echo ">>>> Checking Resource: ${RESOURCE} with name ${RESOURCE_NAME}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        if [[ $(oc --kubeconfig=${KUBE} -n ${NAMESPACE} get ${RESOURCE} ${RESOURCE_NAME} -o jsonpath="{.status.conditions[?(@.type==\"${TYPE_STATUS}\")].status}") == 'True' ]]; then
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

function render_file() {
    SOURCE_FILE=${1}
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function fill_ui_vars() {
    echo ">>>> Filling Vars for UI deployment on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    export UI_NS=kubeframe-ui
    export UI_IMAGE="quay.io/ztpfw/ui:latest"
    export UI_ROUTE_HOST="kubeframe-ui-${UI_NS}.${SPOKE_INGRESS_NAME}"
    export UI_APP_URL="https://${UI_ROUTE_HOST}"
 
    echo ">> UI Parameters:"
    echo "NAMESPACE: ${UI_NS}"
    echo "IMAGE: ${UI_IMAGE}"
    echo "ROUTE_HOST ${UI_ROUTE_HOST}"
    echo "APP_URL: ${UI_APP_URL}"
}

function deploy_ui() {
    echo ">>>> Deploying the User Interface into: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc create namespace ${UI_NS} -o yaml --dry-run=client | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
    render_file manifests/deployment.yaml
    render_file manifests/oauth-client.yaml
    render_file manifests/service.yaml
    render_file manifests/route.yaml
}

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}
do
    extract_kubeconfig_common ${spoke}
    grab_api_ingress ${spoke}
    fill_ui_vars ${spoke}
    deploy_ui ${spoke}
    check_resource "deployment" "kubeframe-ui" "Available" "${UI_NS}" "${SPOKE_KUBECONFIG}"
    echo ">> UI Deployment done in: ${spoke}"
done
