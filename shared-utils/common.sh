#!/bin/bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration SPOKES_FILE defined in $SPOKES_FILE

echo ">>>> Grabbing info from configuration SPOKES_FILE at ${SPOKES_FILE}"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

# SPOKES_FILE variable must be exported in the environment
if [ ! -f "${SPOKES_FILE}" ]; then
	echo "File ${SPOKES_FILE} does not exist"
	exit 1
fi

export OC_RHCOS_RELEASE=$(yq eval ".config.OC_RHCOS_RELEASE" ${SPOKES_FILE})
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${SPOKES_FILE})
export OC_OCP_TAG$(yq eval ".config.OC_OCP_TAG" ${SPOKES_FILE})
export OC_OCP_VERSION=$(yq eval ".config.OC_OCP_VERSION" ${SPOKES_FILE})
export WORKDIR=${GITHUB_WORKSPACE}