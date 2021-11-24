#!/bin/bash

function create_cs() {
	cat >./catalogsource.yaml <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: kubeframe-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: ${OLM_DESTINATION_INDEX}
  displayName: Disconnected Lab
  publisher: disconnected-lab
  updateStrategy:
    registryPoll:
      interval: 30m
EOF

	echo ""
	echo "To apply the Red Hat Operators catalog mirror configuration to your cluster, do the following once per cluster:"
	echo "oc apply -f ./catalogsource.yaml"
}

function prepare_env() {
	## Load Env
	source ./common.sh ${1}

	## Checks
	fail_counter=0
	for binary in {opm,oc,skopeo,podman}; do
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
		#exit 1
	fi

	echo ">>>> Creating Namespace and Service Accounts"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	if [ $(oc get ns | grep olm | wc -l) -eq 0 ]; then
		oc create ns ${OLM_DESTINATION_REGISTRY_IMAGE_NS}
	fi

	oc -n ${OLM_DESTINATION_REGISTRY_IMAGE_NS} create sa robot
	oc -n ${OLM_DESTINATION_REGISTRY_IMAGE_NS} adm policy add-role-to-user registry-editor -z robot
}

function mirror() {
	# Check for credentials for OPM
	if [ ! -f ~/.docker/config.json ]; then
		echo "ERROR: missing ~/.docker/config.json config"
		exit 1
	fi

	echo ">>>> Mirror OLM Operators"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
	echo "Pull Secret: ${PULL_SECRET}"
	echo "Source Index: ${SOURCE_INDEX}"
	echo "Source Packages: ${SOURCE_PACKAGES}"
	echo "Destination Index: ${OLM_DESTINATION_INDEX}"
	echo "Destination Registry: ${DESTINATION_REGISTRY}"
	echo "Destination Namespace: ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}"
	# Mirror redhat-operator index image
	echo "opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"
	opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}
	GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}
	GODEBUG=x509ignoreCN=0 oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}
}

prepare_env ${1}
mirror
create_cs

exit 0
