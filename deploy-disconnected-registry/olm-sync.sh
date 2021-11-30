#!/bin/bash

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

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
}

function mirror() {
	# Check for credentials for OPM
	#echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
	#echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	#podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}

	if [ ! -f ~/.docker/config.json ]; then
		echo "ERROR: missing ~/.docker/config.json config"
		echo "Creating file"
		unalias cp || echo "Unaliased cp: Done!"
		mkdir -p ~/.docker/
		cp -rf ${PULL_SECRET} ~/.docker/config.json
	fi

	echo ">>>> Mirror OLM Operators"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
	echo "Pull Secret: ${PULL_SECRET}"
	echo "Source Index: ${SOURCE_INDEX}"
	echo "Source Packages: ${SOURCE_PACKAGES}"
	echo "Destination Index: ${OLM_DESTINATION_INDEX}"
	echo "Destination Registry: ${DESTINATION_REGISTRY}"
	echo "Destination Namespace: ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>"

	# Mirror redhat-operator index image
	echo "opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"
	opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}
	GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}

	echo ">>>> Trying to push OLM images to Internal Registry"
	GODEBUG=x509ignoreCN=0 oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}

	PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
	for packagemanifest in $(oc get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
		for package in $(oc get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
			echo
			echo "Package: ${package}"
			skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
		done
	done
}
if [[ "$1" == 'hub' ]]; then
    if ! ./verify_olm_sync.sh ; then
		prepare_env ${1}
		mirror
		create_cs
	else
		echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
	fi
fi
