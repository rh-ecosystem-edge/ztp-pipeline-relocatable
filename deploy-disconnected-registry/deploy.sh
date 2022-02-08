#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh ${1}

function render_file() {
    SOURCE_FILE=${1}
    MODE=${2}
    if [[ $# -lt 2 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <MODE> [<SPOKE_NAME>]"
        exit 1
    fi
    if [[ ${MODE} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=hub
    elif [[ ${MODE} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        cluster=${3}
    fi
    envsubst <${SOURCE_FILE} | oc --kubeconfig=${TARGET_KUBECONFIG} apply -f -
}

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${SPOKE_KUBECONFIG}
}

function check_mcp() {
    MODE=${1}

    echo Mode: ${MODE}
    if [[ ${MODE} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=hub
    elif [[ ${MODE} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        cluster=${2}
    fi
    echo ">> Waiting for the MCO to grab the new MachineConfig for the certificate..."
    sleep 120

    echo ">>>> Waiting for MCP Updated field on: ${MODE}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        echo KUBECONFIG=${TARGET_KUBECONFIG}
        if [[ $(oc --kubeconfig=${TARGET_KUBECONFIG} get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}') == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for MCP Updated field on: ${MODE}"
        sleep 5
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for MCP Updated field on: ${MODE}"
        exit 1
    fi
}

function check_ocs_ready() {
    echo ">>>> Waiting for OCS Cluster Ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} -n openshift-storage storagecluster -ojsonpath='{.items[*].status.phase}') == "Ready" ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for OCS deployment to be ready..."
        exit 1
    fi
}

function check_route_ready() {
    echo ">>>> Waiting for registry route Ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "240" ]; do
        if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} route -n ${REGISTRY} --no-headers | wc -l) -eq 3 ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for Registry route t to be ready..."
        exit 1
    fi
}

function deploy_registry() {

    if [[ ${MODE} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=hub
        echo ">>>> Deploy internal registry: ${REGISTRY} - Namespace: (${cluster})"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        # TODO: Render variables instead being static
        oc create namespace ${REGISTRY} -o yaml --dry-run=client | oc --kubeconfig=${TARGET_KUBECONFIG} apply -f -
        htpasswd -bBc ${AUTH_SECRET} ${REG_US} ${REG_PASS}
        oc -n ${REGISTRY} create secret generic ${SECRET} --from-file=${AUTH_SECRET} -o yaml --dry-run=client | oc --kubeconfig=${TARGET_KUBECONFIG} apply -f -
        oc -n ${REGISTRY} create configmap registry-conf --from-file=config.yml -o yaml --dry-run=client | oc --kubeconfig=${TARGET_KUBECONFIG} apply -f -
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/deployment.yaml
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/service.yaml
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/pvc-registry.yaml
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/route.yaml
    elif [[ ${MODE} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        cluster=${2}
        echo ">>>> Deploy internal Quay Registry: ${REGISTRY} - Namespace: (${cluster})"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        # TODO: Render variables instead being static
        # check if ocs is ready before deploying registry
        check_ocs_ready

        # Create the registry deployment and wait for it
        echo ">> Creating the registry deployment"
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${QUAY_MANIFESTS}/quay-operator.yaml
        QUAY_OPERATOR=$(oc --kubeconfig=${TARGET_KUBECONFIG} -n quay get deployment -o name | grep quay-operator |cut -d '/' -f 2)
        echo ">> Waiting for the registry deployment to be ready"
        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${QUAY_OPERATOR}"

        # Create the config for the registry
        echo ">> Creating the config for the registry"
        oc create -n ${REGISTRY} secret generic --from-file config.yaml=${QUAY_MANIFESTS}/config.yaml config-bundle-secret


        # Create the registry Quay CR
        echo ">> Creating the registry Quay CR"
        oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${QUAY_MANIFESTS}/quay-cr.yaml
        sleep 60 # wait for the firsts pods and deployment
        echo ">> Waiting for the registry Quay CR to be ready"
        for dep in $(oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} get deployment -o name | grep kubeframe-registry |cut -d '/' -f 2); do
            echo ">> waiting for deployment ${dep} in Quay operator to be ready"
            ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${dep}"
        done

        # wait for route to be ready
        echo ">> Waiting for the registry route to be ready"
        check_route_ready

        # Get URL for api
        APIURL="https://${DESTINATION_REGISTRY}/api/v1/user/initialize"

        # Call quay API to enable the dummy user
        echo ">> Calling quay API to enable the user"
        curl -X POST -k ${APIURL} --header 'Content-Type: application/json' --data '{ "username": "dummy", "password":"dummy", "email": "quayadmin@example.com", "access_token": true}'
    fi

}

function trust_internal_registry() {

    if [[ ${MODE} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster="hub"
    elif [[ ${MODE} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        cluster=${spoke}
    fi

    echo ">>>> Trusting internal registry"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    ## Update trusted CA from Helper
    #TODO despues el sync pull secret global porque crictl no puede usar flags y usa el generico with https://access.redhat.com/solutions/4902871
    export CA_CERT_DATA=$(oc --kubeconfig=${TARGET_KUBECONFIG} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}')
    export PATH_CA_CERT="/etc/pki/ca-trust/source/anchors/internal-registry-${cluster}.crt"

    echo "${CA_CERT_DATA}" | base64 -d >"${PATH_CA_CERT}" #update for the hub/hypervisor
    update-ca-trust extract

}

MODE=${1}
if [[ ${MODE} == 'hub' ]]; then
    if ! ./verify.sh "${MODE}"; then
        deploy_registry ${MODE}
        trust_internal_registry ${MODE}
        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${REGISTRY}"
        render_file manifests/machine-config-certs.yaml ${MODE}
        # after machine config is applied, we need to wait for the registry and acm pods and deployments to be ready
        check_mcp "${MODE}"
        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${REGISTRY}"
    else
        echo ">>>> This step to deploy registry on Hub is not neccesary, everything looks ready"
    fi
elif [[ ${MODE} == 'spoke' ]]; then

    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    for spoke in ${ALLSPOKES}; do
        # Get Spoke Kubeconfig
        echo "spoke: ${spoke}"
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig ${spoke}
        else
            export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi

        # Verify step
        if ! ./verify.sh "${MODE}"; then
            deploy_registry ${MODE} ${spoke}
            trust_internal_registry ${MODE} ${spoke}

            # TODO: Implement KUBECONFIG as a parameter in wait_for_deployment.sh file
            export KUBECONFIG=${SPOKE_KUBECONFIG}
            ../"${SHARED_DIR}"/wait_for_deployment.sh -t 10000 -n "${REGISTRY}" "${REGISTRY}"
            export KUBECONFIG=${KUBECONFIG_HUB}

            # updated with machine config
            render_file manifests/machine-config-certs.yaml ${MODE} ${spoke}
            check_mcp "${MODE}" "${spoke}"
        else
            echo ">>>> This step to deploy registry on Spoke: ${spoke} is not neccesary, everything looks ready"
        fi
    done
fi
