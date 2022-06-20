#!/usr/bin/env bash
set -o pipefail
set -o nounset
set -o errexit
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# debug options
debug_status starting

function generate_mapping() {
    echo ">>>> Creating OLM Manifests"
    echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TGT_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests"
    GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TGT_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests
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
source ./common.sh ${1}

if [[ ${1} == 'hub' ]]; then
    TGT_KUBECONFIG=${KUBECONFIG_HUB}
elif [[ ${1} == 'edgecluster' ]]; then
    TGT_KUBECONFIG=${EDGE_KUBECONFIG}
fi

echo ">>>> Verifying OLM Sync: ${1}"
registry_login ${DESTINATION_REGISTRY}
for packagemanifest in $(oc --kubeconfig=${TGT_KUBECONFIG} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
    for package in $(oc --kubeconfig=${TGT_KUBECONFIG} get ${packagemanifest} -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
        echo "Verify Package: ${package}"
        #if next command fails, it means that the image is not already in the destination registry, so output command will be error (>0)
        skopeo inspect docker://"${DESTINATION_REGISTRY}"/"${OLM_DESTINATION_REGISTRY_IMAGE_NS}"/$(echo ${package} | awk -F'/' '{print $2}')-$(basename ${package}) --authfile "${PULL_SECRET}"
    done
done

echo ">>>> Verifying Certified OLM Sync: ${1}"
registry_login ${DESTINATION_REGISTRY}
for packagemanifest in $(oc --kubeconfig=${TGT_KUBECONFIG} get packagemanifest -n openshift-marketplace -o name ${CERTIFIED_PACKAGES_FORMATED}); do
    for package in $(oc --kubeconfig=${TGT_KUBECONFIG} get ${packagemanifest} -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
        echo "Verify Package: ${package}"
        #if next command fails, it means that the image is not already in the destination registry, so output command will be error (>0)
        skopeo inspect docker://"${DESTINATION_REGISTRY}"/"${OLM_DESTINATION_REGISTRY_IMAGE_NS}"/$(echo ${package} | awk -F'/' '{print $2}')-$(basename ${package}) --authfile "${PULL_SECRET}"
    done
done
#In this case, we don't need to mirror catalogs, everything is already there

recover_mapping
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"
# debug options
debug_status ended
exit 0
