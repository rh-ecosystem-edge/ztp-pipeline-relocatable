#!/usr/bin/env bash

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting SPOKE_KUBECONFIG: ${SPOKE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${SPOKE_KUBECONFIG}
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

    for a in {1..30}; do
        skopeo login ${REG} --authfile=${PULL_SECRET} --username ${REG_US} --password ${REG_PASS}
        if [[ $? -eq 0 ]]; then
            echo "Registry: ${REG} available"
            break
        fi
        sleep 10
    done
}

function mirror() {
    # Check for credentials for OPM
    if [[ ${1} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    elif [[ ${1} == 'spoke' ]]; then
        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}
        echo ">>>> Checking Source Registry: ${SOURCE_REGISTRY}"
        check_registry ${SOURCE_REGISTRY}
        echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    fi

    echo ">>>> Podman Login into Source Registry: ${SOURCE_REGISTRY}"
    ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
    ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS}
    echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
    ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
    ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS}

    if [ ! -f ~/.docker/config.json ]; then
        echo "ERROR: missing ~/.docker/config.json config"
        echo "Creating file"
        unalias cp &>/dev/null || echo "Unaliased cp: Done!"
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
    echo "Mirror Mode: ${MIRROR_MODE}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"

    if [[ ${MIRROR_MODE} == 'auto' ]]; then
        mirror_auto
    elif [[ ${MIRROR_MODE} == 'skopeo' ]]; then
        mirror_skopeo
    elif [[ ${MIRROR_MODE} == 'all' ]]; then
        mirror_auto
        #mirror_auto
        mirror_skopeo
    fi
}

function mirror_auto() {
    # Mirror redhat-operator index image
    echo "DEBUG: opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"

    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    export STORAGE_DRIVER=vfs
    sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######

    opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}

    echo "DEBUG: GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}"
    GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}

    # Mirror redhat-operator packages
    echo ">>>> Trying to push OLM images to Internal Registry"
    echo "DEBUG: GODEBUG=x509ignoreCN=0 oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}"
    GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100 2>&1 | tee ${OUTPUTDIR}/mirror.log

    cat ${OUTPUTDIR}/mirror.log | grep 'error:' >${OUTPUTDIR}/mirror-error.log

}

function mirror_skopeo() {
    # Patch to avoid issues on mirroring
    FAILEDPACKAGES=$(cat ${OUTPUTDIR}/mirror-error.log | tr ": " "\n" | grep ${DESTINATION_REGISTRY} | sed "s/${DESTINATION_REGISTRY}//g" | sed "s#^/##g" | sort -u | xargs echo)

    echo ">> Packages that have failed START"
    echo ${FAILEDPACKAGES}
    echo ">> Packages that have failed END"

    PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
    for packagemanifest in $(oc --kubeconfig=${KUBECONFIG_HUB} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
        for package in $(oc --kubeconfig=${KUBECONFIG_HUB} get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
            for pkg in ${FAILEDPACKAGES}; do
                if [[ $(echo ${package} | grep -q ${pkg}) ]]; then
                    echo
                    echo "Package: ${package}"
                    echo "DEBUG: skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}"
                    skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
                    if [[ ${?} != 0 ]]; then
                        echo "Error on Image Copy, retrying after 5 seconds..."
                        sleep 10
                        skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
                    fi
                    sleep 1
                fi
            done
        done
    done

    # Copy extra images to the destination registry
    for image in ${EXTRA_IMAGES}; do
        echo "Image: ${image}"
        echo "skopeo copy docker://${image} docker://${DESTINATION_REGISTRY}/${image#*/} --all --authfile ${PULL_SECRET}"
        skopeo copy docker://${image} docker://${DESTINATION_REGISTRY}/${image#*/} --all --authfile ${PULL_SECRET}
        # sleep 1
    done
}

if [[ ${1} == 'hub' ]]; then
    prepare_env 'hub'
    create_cs 'hub'
    trust_internal_registry 'hub'
    if ! ./verify_olm_sync.sh 'hub'; then
        mirror 'hub'
    else
        echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
    fi
elif [[ ${1} == "spoke" ]]; then
    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    for spoke in ${ALLSPOKES}; do
        # Get Spoke Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig ${spoke}
        else
            export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi
        prepare_env 'spoke'
        create_cs 'spoke' ${spoke}
        trust_internal_registry 'hub'
        trust_internal_registry 'spoke' ${spoke}
        if ! ./verify_olm_sync.sh 'spoke'; then
            mirror 'spoke'
        else
            echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
        fi
    done
fi
