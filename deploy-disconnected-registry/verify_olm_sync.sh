#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function generate_mapping() {
    echo ">>>> Creating OLM Manifests"
    echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests"
    GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests
    echo ">>>> Copying mapping file to ${OUTPUTDIR}/mapping.txt"
    cp -f ${OUTPUTDIR}/olm-manifests/mapping.txt ${OUTPUTDIR}/mapping.txt
}

function recover_mapping() {
    MAP_FILENAME='mapping.txt'
    echo ">>>> Finding Map file for OLM Sync"
    if [[ ! -f "${OUTPUTDIR}/${MAP_FILENAME}" ]]; then
        echo ">>>> No mapping file found for OLM Sync"
        MAP="${OUTPUTDIR}/${MAP_FILENAME}"
        find ${OUTPUTDIR} -name "${MAP_FILENAME}*" -exec cp {} ${MAP} \;
        if [[ ! -f ${MAP} ]]; then
            generate_mapping
        fi
    fi
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh ${MODE}

MODE=${1}

if [[ ${MODE} == 'hub' ]]; then
    TARGET_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${MODE} == 'spoke' ]]; then
    TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
fi

echo ">>>> Verifying OLM Sync: ${MODE}"
podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
for packagemanifest in $(oc --kubeconfig=${TARGET_KUBECONFIG} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
    for package in $(oc --kubeconfig=${TARGET_KUBECONFIG} get ${packagemanifest} -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
        echo "Verify Package: ${package}"
        #if next command fails, it means that the image is not already in the destination registry, so output command will be error (>0)
        skopeo inspect docker://"${DESTINATION_REGISTRY}"/"${OLM_DESTINATION_REGISTRY_IMAGE_NS}"/$(echo ${package} | awk -F'/' '{print $2}')-$(basename ${package}) --authfile "${PULL_SECRET}"
    done
done
#In this case, we don't need to mirror catalogs, everything is already there

recover_mapping

exit 0
