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
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function fill_ui_vars() {
    echo ">>>> Filling Vars for UI deployment on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    export UI_NS=ztpfw-ui
    export UI_IMAGE="quay.io/ztpfw/ui:latest"
    export UI_ROUTE_HOST="edge-cluster-setup.${SPOKE_INGRESS_NAME}"
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
    render_file manifests/clusterrolbinding.yaml
}

function verify_ui() {
    echo ">>>> Verifying deployment of the user interface on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    curl ${UI_APP_URL} -k -m 30
}

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
    extract_kubeconfig_common ${spoke}
    grab_api_ingress ${spoke}
    fill_ui_vars ${spoke}
    deploy_ui ${spoke}
    check_resource "deployment" "ztpfw-ui" "Available" "${UI_NS}" "${SPOKE_KUBECONFIG}"
    verify_ui ${spoke}
    echo ">> UI Deployment done in: ${spoke}"
done
