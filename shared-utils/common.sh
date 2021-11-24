#!/bin/bash
# Description: Reads/sets environment variables for the scripts to run, parsing information from the configuration YAML defined in $YAML

echo ">>>> Grabbing info from configuration yaml at ${YAML}"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

# YAML variable must be exported in the environment
if [ ! -f "${YAML}" ]; then
	echo "File ${YAML} does not exist"
	exit 1
fi

export OC_RHCOS_RELEASE=$(yq eval ".config.OC_RHCOS_RELEASE" ${YAML})
export OC_ACM_VERSION=$(yq eval ".config.OC_ACM_VERSION" ${YAML})
export OC_OCP_TAG$(yq eval ".config.OC_OCP_TAG" ${YAML})
export OC_OCP_VERSION=$(yq eval ".config.OC_OCP_VERSION" ${YAML})
