#!/bin/bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration YAML defined in ${SPOKES_FILE}
# SPOKES_FILE variable must be exported in the environment

echo ">>>> Grabbing info from configuration yaml at ${SPOKES_FILE}"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

# SPOKES_FILE variable must be exported in the environment
if [ ! -f "${SPOKES_FILE}" ]; then
	echo "File ${SPOKES_FILE} does not exist"
	exit 1
fi

export OC_RHCOS_RELEASE=$(yq eval ".config.OC_RHCOS_RELEASE" ${SPOKES_FILE})
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${SPOKES_FILE})
export OC_OCP_TAG=$(yq eval ".config.OC_OCP_TAG" ${SPOKES_FILE})
export OC_OCP_VERSION=$(yq eval ".config.OC_OCP_VERSION" ${SPOKES_FILE})

export OUTPUTDIR=${WORKDIR}/build

[ -d ${OUTPUTDIR} ] || mkdir -p ${OUTPUTDIR}

export KUBECONFIG_HUB=${KUBECONFIG}
export PULL_SECRET=${OUTPUTDIR}/pull-secret.json

if [[ ! -f ${PULL_SECRET} ]]; then
	echo "Pull secret file ${PULL_SECRET} does not exist, grabbing from OpenShift"
	oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d >${PULL_SECRET}
fi
