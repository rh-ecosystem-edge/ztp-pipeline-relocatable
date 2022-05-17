#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

source ${WORKDIR}/shared-utils/common.sh

function render_file() {
    SOURCE_FILE=${1}
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function fill_ui_vars() {
    echo ">>>> Filling Vars for UI deployment on: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    export UI_NS=ztpfw-ui
    export UI_IMAGE="quay.io/ztpfw/ui:latest"
    export UI_ROUTE_HOST="edge-cluster-setup.${EDGE_INGRESS_NAME}"
    export UI_APP_URL="https://${UI_ROUTE_HOST}"

    echo ">> UI Parameters:"
    echo "NAMESPACE: ${UI_NS}"
    echo "IMAGE: ${UI_IMAGE}"
    echo "ROUTE_HOST ${UI_ROUTE_HOST}"
    echo "APP_URL: ${UI_APP_URL}"
}

function deploy_ui() {
    echo ">>>> Deploying the User Interface into: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    oc create namespace ${UI_NS} -o yaml --dry-run=client | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
    render_file manifests/deployment.yaml
    render_file manifests/oauth-client.yaml
    render_file manifests/service.yaml
    render_file manifests/route.yaml
    render_file manifests/clusterrolbinding.yaml
}

function verify_ui() {
    echo ">>>> Verifying deployment of the user interface on: ${edgecluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    curl ${UI_APP_URL} -k -m 30
}

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

for edgecluster in ${ALLEDGECLUSTERS}; do
    extract_kubeconfig_common ${edgecluster}
    grab_api_ingress ${edgecluster}
    fill_ui_vars ${edgecluster}
    deploy_ui ${edgecluster}
    check_resource "deployment" "ztpfw-ui" "Available" "${UI_NS}" "${EDGE_KUBECONFIG}"
    verify_ui ${edgecluster}
    echo ">> UI Deployment done in: ${edgecluster}"
done
