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

function create_cs() {
    if [[ ${MODE} == 'hub' ]]; then
        CS_OUTFILE=${OUTPUTDIR}/catalogsource-hub.yaml
    elif [[ ${MODE} == 'spoke' ]]; then
        CS_OUTFILE=${OUTPUTDIR}/catalogsource-${spoke}.yaml
    fi

	cat > ${CS_OUTFILE} <<EOF

apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${OC_DIS_CATALOG}
  namespace: ${MARKET_NS}
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
	echo "oc apply -f ${CS_OUTFILE}"
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
		exit 1
	fi
}

function check_registry() {
    REG=${1}

    for a in {1..30}
    do
        skopeo login ${REG} --authfile=${PULL_SECRET} --username ${REG_US} --password ${REG_PASS}
        if [[ $? -eq 0 ]];then
            echo "Registry: ${REG} available"
            break
        fi
        sleep 10
    done
}


function mirror() {
	# Check for credentials for OPM
    if [[ ${MODE} == 'hub' ]];then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
	    echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    elif [[ ${MODE} == 'spoke' ]];then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
	    echo ">>>> Checking Source Registry: ${DESTINATION_REGISTRY}"
        check_registry ${SOURCE_REGISTRY}
	    echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    fi

	echo ">>>> Podman Login into Source Registry: ${SOURCE_REGISTRY}"
	podman login ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
	echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
	podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}

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
    echo "Target Kubeconfig: ${TARGET_KUBECONFIG}"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>"

	# Mirror redhat-operator index image
	echo "DEBUG: opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"
	opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}

    echo "DEBUG: GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}"
	GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}

	echo ">>>> Trying to push OLM images to Internal Registry"
    echo "DEBUG: GODEBUG=x509ignoreCN=0 oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}"
	GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}

    # Patch to avoid issues on mirroring
	PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
	for packagemanifest in $(oc --kubeconfig=${KUBECONFIG_HUB} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
		for package in $(oc --kubeconfig=${KUBECONFIG_HUB} get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
			echo
			echo "Package: ${package}"
			skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
		done
	done

    # Copy extra images to the destination registry
    for image in ${EXTRA_IMAGES}
    do
        echo "Image: ${image}"
        echo "skopeo copy docker://${image} docker://${DESTINATION_REGISTRY}/${image#*/} --all --authfile ${PULL_SECRET}"
        skopeo copy docker://${image} docker://${DESTINATION_REGISTRY}/${image#*/} --all --authfile ${PULL_SECRET}
    done
}

MODE=${1}

if [[ ${MODE} == 'hub' ]]; then
	prepare_env ${MODE}
	create_cs ${MODE}
	if ! ./verify_olm_sync.sh ${MODE}; then
		mirror ${MODE}
	else
		echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
	fi
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
		prepare_env ${MODE}
		create_cs ${MODE}
		if ! ./verify_olm_sync.sh ${MODE}; then	
			mirror ${MODE}
		else
			echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
		fi
    done
fi
