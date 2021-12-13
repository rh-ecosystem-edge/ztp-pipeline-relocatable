#!/bin/bash

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]];then 
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting SPOKE_KUBECONFIG: ${SPOKE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath=‘{.data.kubeconfig}’ | base64 -d > ${SPOKE_KUBECONFIG}
}

function prepare_env() {
	## Load Env
	source ./common.sh ${1}

	## Checks
	fail_counter=0
	for binary in {oc,podman}; do
		if [[ -z $(command -v $binary) ]]; then
			echo "You need to install $binary!"
			let "fail_counter++"
		fi
	done

	if [[ ! -f ${PULL_SECRET} ]]; then
		echo ">> Pull Secret not found in ${PULL_SECRET}!"
		let "fail_counter++"
	fi

	if [[ ${fail_counter} -ge 1 ]]; then
		echo "#########"
		exit 1
	fi
}

MODE=${1}

if [[ ${MODE} == 'hub' ]]; then

	prepare_env ${MODE}
	podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
	oc --kubeconfig=${KUBECONFIG_HUB} set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${PULL_SECRET}

elif [[ ${1} == "spoke" ]]; then
    if [[ -z "${ALLSPOKES}" ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi
    
    for spoke in ${ALLSPOKES}
    do
        # Get Spoke Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig ${spoke}
        else
            export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi
		source ./common.sh ${MODE}

		prepare_env ${MODE}
		podman login ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
		podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
		oc --kubeconfig=${SPOKE_KUBECONFIG} set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=${PULL_SECRET}

    done
fi
