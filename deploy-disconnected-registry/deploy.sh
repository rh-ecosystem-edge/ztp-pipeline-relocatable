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
    if [[ $# -lt 2 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <MODE> [<EDGE_NAME>]"
        exit 1
    fi
    if [[ ${2} == 'hub' ]]; then
        cluster='hub'
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${KUBECONFIG_HUB} apply -f -
    elif [[ ${2} == 'edgecluster' ]]; then
        cluster=${3}
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
    fi
}

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $edgecluster $edgecluster-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${EDGE_KUBECONFIG}
}

function check_mcp() {

    echo Mode: ${1}
    if [[ ${1} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=hub
    elif [[ ${1} == 'edgecluster' ]]; then
        TARGET_KUBECONFIG=${EDGE_KUBECONFIG}
        cluster=${2}
    fi
    echo ">> Waiting for the MCO to grab the new MachineConfig for the certificate..."
    sleep 120

    echo ">>>> Waiting for MCP Updated field on: ${1}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    echo KUBECONFIG=${TARGET_KUBECONFIG}
    while [ "$timeout" -lt "1000" ]; do
        echo "Nodes:"
        oc --kubeconfig=${TARGET_KUBECONFIG} get nodes
        echo
        echo "MCP:"
        oc --kubeconfig=${TARGET_KUBECONFIG} get mcp
        echo
        if [[ $(oc --kubeconfig=${TARGET_KUBECONFIG} get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}') == 'True' ]]; then
            ready=true
            break
        fi
        echo "Waiting for MCP Updated field on: ${1}"
        sleep 20
        side_evict_error ${TARGET_KUBECONFIG}
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for MCP Updated field on: ${1}"
        exit 1
    fi
}

function check_odf_ready() {
    echo ">>>> Waiting for ODF Cluster Ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} -n openshift-storage storagecluster -ojsonpath='{.items[*].status.phase}') == "Ready" ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done
    if [ "$ready" == "false" ]; then
        echo "timeout waiting for ODF deployment to be ready..."
        exit 1
    fi
}

function check_route_ready() {
    echo ">>>> Waiting for registry route Ready"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    timeout=0
    ready=false
    while [ "$timeout" -lt "1000" ]; do
        if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} route -n ${REGISTRY} --no-headers | wc -l) -ge 3 ]]; then
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

function deploy_docker_registry() {
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
     REGISTRY_URI="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
     oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} create configmap ztpfw-config -o yaml --from-literal=uri=$(echo ${REGISTRY_URI} | base64 -w0 )
}

function deploy_quay_registry() {
    cluster=${2}
    echo ">>>> Deploy internal Quay Registry: ${REGISTRY} - Namespace: (${cluster})"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    # TODO: Render variables instead being static
    # check if odf is ready before deploying registry
    check_odf_ready
    
    # Create the registry deployment and wait for it
    echo ">> Creating the registry deployment"
    oc --kubeconfig=${EDGE_KUBECONFIG} -n ${REGISTRY} apply -f ${QUAY_MANIFESTS}/quay-operator.yaml
    	QUAY_STATUS=false
    	echo "INFO: waiting for Quay Operator to be ready ( 3 min )" 
    	for i in {1..18}
    	do
    		if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get csv -n ${REGISTRY} -l operators.coreos.com/quay-operator.ztpfw-registry -o jsonpath='{.items[*].status.phase}' 2>/dev/null ) == "Succeeded" ]]; then
    			QUAY_STATUS=True
    			break
    		fi
    		sleep 10
    	done
    	if [[ "${QUAY_STATUS}" == "false" ]]; then
    		echo "Error: Quay operator failed to start"
    		exit 1
    	fi
    QUAY_OPERATOR=$(oc --kubeconfig=${EDGE_KUBECONFIG} -n "${REGISTRY}" get deployment -o name | grep quay-operator | cut -d '/' -f 2)
    echo ">> Waiting for the registry deployment to be ready"
    check_resource "deployment" "${QUAY_OPERATOR}" "Available" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    
    # Create the config for the registry
    echo ">> Creating the config for the registry"
    oc create --kubeconfig=${EDGE_KUBECONFIG} -n ${REGISTRY} secret generic --from-file config.yaml=${QUAY_MANIFESTS}/config.yaml config-bundle-secret
    
    # Create the registry Quay CR
    echo ">> Creating the registry Quay CR"
    oc --kubeconfig=${EDGE_KUBECONFIG} -n ${REGISTRY} apply -f ${QUAY_MANIFESTS}/quay-cr.yaml
    # sleep 240 # wait for the firsts pods and deployment
    echo ">> waiting for deployment ztpfw-registry-quay-app in Quay operator to be ready"
    check_resource "quayregistry" "ztpfw-registry" "ComponentPostgresReady" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    check_resource "quayregistry" "ztpfw-registry" "ComponentQuayReady" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    check_resource "quayregistry" "ztpfw-registry" "ComponentRouteReady" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    check_resource "quayregistry" "ztpfw-registry" "ComponentsCreated" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    check_resource "quayregistry" "ztpfw-registry" "Available" "${REGISTRY}" "${EDGE_KUBECONFIG}"
    
    # wait for route to be ready
    echo ">> Waiting for the registry route to be ready"
    check_route_ready
}
    

function initialize_quay() {
    check_resource "quayregistry" "ztpfw-registry" "ComponentRouteReady" "${REGISTRY}" "${EDGE_KUBECONFIG}"

    # Get URL for api
    timeout=0
    while [ "${timeout}" -lt "1000" ]; do
    	ROUTE="$(oc --kubeconfig=${EDGE_KUBECONFIG} get route -n ${REGISTRY} ${REGISTRY}-quay -o jsonpath={'.status.ingress[0].host'})"
	if [[ "${ROUTE}" != "" ]];
	then
	    break
	fi
        sleep 10
        timeout=$((timeout + 1))
    done

    echo ">>>>>>>>>>> https://${ROUTE}/api/v1/user/initialize "
    APIURL="https://${ROUTE}/api/v1/user/initialize"
    
    TOKEN=$(oc --kubeconfig=${EDGE_KUBECONFIG} extract -n ${REGISTRY} secret/quay-token  --to -)

    if [[ "$?" -ne 0 ]];
    then
        # Call quay API to enable the dummy user
        echo ">> INFO: Creating Quay Creds"
        export REG_US="dummy"
        export REG_PASS="dummy123"
        export REG_EMAIL="quayadmin@example.com"
        
        DATA_JSON_PATH="${OUTPUTDIR}/quay-user-update.json"
        cp "${WORKDIR}/deploy-disconnected-registry/quay-manifests/quay-user-update.json" "${DATA_JSON_PATH}"
        
        sed -i "s/QUAY_USER/${REG_US}/g" "${DATA_JSON_PATH}"
        sed -i "s/QUAY_PASS/${REG_PASS}/g" "${DATA_JSON_PATH}"
        sed -i "s/QUAY_EMAIL/${REG_EMAIL}/g" "${DATA_JSON_PATH}"
        
        	
        # Call quay API to enable the dummy user
        echo ">> INFO: Calling quay API to enable the user"
        RESULT=$(curl -s -X POST -k ${APIURL} --header 'Content-Type: application/json' --data "@${DATA_JSON_PATH}")
        
        if [[ "$?" -ne 0 ]];
        then
            exit $?
        fi

        TOKEN=$(echo ${RESULT} | jq -r '.access_token')
        oc --kubeconfig=${EDGE_KUBECONFIG} create secret generic -n ${REGISTRY} quay-token --from-literal=token="${TOKEN}"
    fi
    
    echo ">> Token from result is: ${TOKEN}"
    
    echo ">> Creating organizations for mirror to succeed"
    APIURL="https://${ROUTE}/api/v1/organization/"
    echo ">> Creating organization ztpfw"
    curl -X POST -k -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" ${APIURL} --data "{\"name\": \"ztpfw\", \"email\": \"ztpfw@redhat.com\"}"
    
    echo ">> INFO: updating pull secret" 
    b64auth=$( echo -n "$REG_US:$REG_PASS" | base64 )
    AUTHSTRING="{\"$ROUTE\": {\"auth\": \"$b64auth\"}}"
    
    echo ">> INFO: getting pull secret"
    oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d > "${OUTPUTDIR}/origin-pullsecret.json"
    
    echo ">> INFO: Creating updated pull secret"
    jq ".auths += $AUTHSTRING" < "${OUTPUTDIR}/origin-pullsecret.json" > "${OUTPUTDIR}/updated-pull-secret.json"
    
    echo ">> INFO: pushing openshift config" 
    oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson="${OUTPUTDIR}/updated-pull-secret.json"

}

function deploy_custom_registry() {
     TMP_REGISTRY_DOMAIN=$( echo  ${CUSTOM_REGISTRY_URL} | cut -d":" -f1 )
     TMP_REGISTRY_PORT=$( echo  ${CUSTOM_REGISTRY_URL} | cut -d":" -f2 )
     TMP_REGISTRY_IP=$( dig  A +short ${TMP_REGISTRY_DOMAIN} | head -1)

     echo "Create Endpoint"
     TPL_MANIFEST="${WORKDIR}/deploy-disconnected-registry/manifests/custom-registry-endpoint.yaml"
     MANIFESTCLONE="${WORKDIR}/build/custom-registry-endpoint.yaml"

     cp -f ${TPL_MANIFEST} ${MANIFESTCLONE}
     sed -i "s/TMP_REGISTRY_DOMAIN/${TMP_REGISTRY_DOMAIN}/g" ${MANIFESTCLONE}
     sed -i "s/TMP_REGISTRY_IP/${TMP_REGISTRY_IP}/g" ${MANIFESTCLONE}
     sed -i "s/TMP_REGISTRY_PORT/${TMP_REGISTRY_PORT}/g" ${MANIFESTCLONE}

     echo "INFO: applying  Endpoint config"
     cat ${MANIFESTCLONE} | yq e -
     oc --kubeconfig=${KUBECONFIG_HUB} create namespace ${REGISTRY} 
     oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${MANIFESTCLONE} 

     echo "INFO: Creating Route"
     oc create route edge ztpfw-registry \
         --kubeconfig=${KUBECONFIG_HUB} --namespace  ${REGISTRY}  \
         --service=external-registry --port=${TMP_REGISTRY_PORT} \
         --insecure-policy=Redirect \
         --dry-run=client --hostname "${TMP_REGISTRY_DOMAIN}" \
         --output=yaml | oc apply -f -

     oc --kubeconfig=${KUBECONFIG_HUB} -n ${REGISTRY} create configmap ztpfw-config -o yaml --from-literal=uri=$(echo ${CUSTOM_REGISTRY_URL} | base64 -w0)
}


if [[ ${1} == 'hub' ]]; then

    if ! ./verify.sh 'hub'; then
        if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
            deploy_docker_registry 'hub'
        elif [[ ${CUSTOM_REGISTRY} == "true" ]]; then
            deploy_custom_registry 'hub'
        fi

        trust_internal_registry 'hub'
        if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
            check_resource "deployment" "${REGISTRY}" "Available" "${REGISTRY}" "${KUBECONFIG_HUB}"
        fi
        check_mcp 'hub'
        render_file manifests/machine-config-certs-worker.yaml 'hub'
        render_file manifests/machine-config-certs-master.yaml 'hub'
        check_resource "mcp" "master" "Updated" "default" "${KUBECONFIG_HUB}"
    else
        echo ">>>> This step to deploy registry on Hub is not neccesary, everything looks ready"
    fi
elif [[ ${1} == 'edgecluster' ]]; then

    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    i=0
    for edgecluster in ${ALLEDGECLUSTERS}; do
        # Get Edge-cluster Kubeconfig
        echo "edgecluster: ${edgecluster}"
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${edgecluster}" ]]; then
            extract_kubeconfig ${edgecluster}
        else
            export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgecluster}"
        fi

        # Verify step
        if ! ./verify.sh 'edgecluster'; then
            if [[ ${CUSTOM_REGISTRY} == "true" ]]; then
                get_external_registry_cert
            fi
            deploy_quay_registry 'edgecluster' ${edgecluster}
            trust_internal_registry 'edgecluster' ${edgecluster}

            echo ">> Updating Node CA Root chain manually"
            recover_edgecluster_rsa ${edgecluster}
            trust_node_certificates ${edgecluster} ${i}

            echo ">> Waiting for the registry Quay CR to be ready after updating the MCP"
            check_resource "deployment" "ztpfw-registry-quay-app" "Available" "${REGISTRY}" "${EDGE_KUBECONFIG}"
        else
            echo ">>>> This step to deploy registry on Edge-cluster: ${edgecluster} is not neccesary, everything looks ready"
        fi

	initialize_quay
        i=$((i + 1))
    done
fi
