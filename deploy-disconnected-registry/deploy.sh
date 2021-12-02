#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh ${1}

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]];then 
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath=‘{.data.kubeconfig}’ | base64 -d > ${SPOKE_KUBECONFIG}
}

function deploy_registry() {
    # TARGET_KUBECONFIG is the KUBECONFIG from the cluster where the Registry will be deployed
    if [[ -z "${1}" ]]; then
        echo "You should pass the Kubeconfig path as a first param"
        exit 1
    fi

    TARGET_KUBECONFIG=${1}
    cluster=${2}

    echo ">>>> Deploy internal registry: ${REGISTRY} Namespace (${cluster})"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	# TODO: Render variables instead being static
	oc --kubeconfig=${TARGET_KUBECONFIG} create namespace ${REGISTRY} -o yaml --dry-run=client | oc apply -f -
	htpasswd -bBc ${AUTH_SECRET} ${REG_US} ${REG_PASS}
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} create secret generic ${SECRET} --from-file=${AUTH_SECRET} -o yaml --dry-run=client | oc apply -f -
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} create configmap registry-conf --from-file=config.yml -o yaml --dry-run=client | oc apply -f -
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/deployment.yaml
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/service.yaml
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/pvc-registry.yaml
	oc --kubeconfig=${TARGET_KUBECONFIG} -n ${REGISTRY} apply -f ${REGISTRY_MANIFESTS}/route.yaml
}

function trust_internal_registry() {
    # Extract ingress TLS cert and import it on the Helper node
    if [[ -z "${1}" ]]; then
        echo "You should pass the Kubeconfig path as a first param"
        exit 1
    fi

    TARGET_KUBECONFIG=${1}
	echo ">>>> Trusting internal registry"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	## Update trusted CA from Helper
	oc --kubeconfig=${TARGET_KUBECONFIG} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d >/etc/pki/ca-trust/source/anchors/internal-registry.crt
	update-ca-trust extract
}

if [[ ${1} == 'hub' ]]; then
	if ! ./verify.sh; then
        deploy_registry ${KUBECONFIG_HUB} 'hub' 
        trust_internal_registry ${KUBECONFIG_HUB}
	    ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${REGISTRY}"
	else
		echo ">>>> This step to deploy registry on ${1} is not neccesary, everything looks ready"
	fi
elif [[ ${1} == 'spoke' ]]; then

    if [[ -z "${ALLSPOKES}" ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi
    
    for spoke in ${ALLSPOKES}
    do
        # Get Spoke Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig ${spoke}
        else
            SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi

        # Verify step
	    if [[ ! ./verify.sh ]]; then
            deploy_registry ${SPOKE_KUBECONFIG} ${spoke} 
            trust_internal_registry ${SPOKE_KUBECONFIG}

            # TODO: Implement KUBECONFIG as a parameter in wait_for_deployment.sh file
            export KUBECONFIG=${SPOKE_KUBECONFIG}
	        ../"${SHARED_DIR}"/wait_for_deployment.sh -t 1000 -n "${REGISTRY}" "${REGISTRY}"
            export KUBECONFIG=${KUBECONFIG_HUB}
	    else
	    	echo ">>>> This step to deploy registry on ${1} is not neccesary, everything looks ready"
	    fi
    done
fi
