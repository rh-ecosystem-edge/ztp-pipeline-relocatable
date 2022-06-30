#!/usr/bin/env bash

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

# debug options
debug_status starting

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting EDGE_KUBECONFIG: ${EDGE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $edgecluster $edgecluster-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${EDGE_KUBECONFIG}
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
    if [[ ${CUSTOM_REGISTRY} == "true" ]]; then
        COMMAND=""
    else
        COMMAND="--username ${REG_US} --password ${REG_PASS}"
    fi

    for a in {1..30}; do
        if [[ $(skopeo login ${REG} --authfile=${PULL_SECRET} ${COMMAND}) ]]; then
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
    elif [[ ${1} == 'edgecluster' ]]; then
        TARGET_KUBECONFIG=${EDGE_KUBECONFIG}
        echo ">>>> Checking Source Registry: ${SOURCE_REGISTRY}"
        check_registry ${SOURCE_REGISTRY}
        echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    fi

    echo ">>>> Podman Login into Source Registry: ${SOURCE_REGISTRY}"
    registry_login ${SOURCE_REGISTRY}
    echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
    registry_login ${DESTINATION_REGISTRY}

    if [ ! -f ~/.docker/config.json ]; then
        echo "INFO: missing ~/.docker/config.json config"
        echo "Creating file"
        unalias cp &>/dev/null || echo "Unaliased cp: Done!"
        mkdir -p ~/.docker/
        cp -rf ${PULL_SECRET} ~/.docker/config.json
    fi

    echo "Copy credentails for opm index"
    mkdir -p /var/run/user/0/containers
    cp -f /workspace/ztp/build/pull-secret.json /var/run/user/0/containers/auth.json

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

    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    export STORAGE_DRIVER=vfs
    sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######

    # Empty log file
    >${OUTPUTDIR}/mirror.log

    # Red Hat Operators
    SALIDA=1

    retry=1
    while [ ${retry} != 0 ]; do
        # Mirror redhat-operator index image
        echo "DEBUG: opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
        opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX} >>${OUTPUTDIR}/mirror.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> Pruning index image finished: ${OLM_DESTINATION_INDEX}"
            retry=0
        else
            echo ">>>> INFO: Failed pruning index image: ${OLM_DESTINATION_INDEX}"
            echo ">>>> INFO: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Pruning index image: ${OLM_DESTINATION_INDEX}"
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    retry=1
    while [ ${retry} != 0 ]; do
        echo "DEBUG: GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
        GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET} >>${OUTPUTDIR}/mirror.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> Push index image finished: ${OLM_DESTINATION_INDEX}"
            retry=0
        else
            echo ">>>> INFO: Failed Pushing index image: ${OLM_DESTINATION_INDEX}"
            echo ">>>> INFO: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Pushing index image: ${OLM_DESTINATION_INDEX}"
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    # Mirror redhat-operator packages
    echo ">>>> Trying to push OLM images to Internal Registry"
    echo "oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100"
    oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100 >>${OUTPUTDIR}/mirror.log 2>&1

    cat ${OUTPUTDIR}/mirror.log | grep 'error:' >${OUTPUTDIR}/mirror-error.log

    # Patch to avoid issues on mirroring
    # In order to match both / and - in the package name we replace them by . that grep with regexp mode can understand
    FAILEDPACKAGES=$(cat ${OUTPUTDIR}/mirror-error.log | tr ": " "\n" | grep ${DESTINATION_REGISTRY} | sed "s/${DESTINATION_REGISTRY}//g" | sed "s#^/##g" | sed 's#-#.#g' | sed 's#olm/##g' | sed 's#/#.#g' | sort -u | xargs echo)

    echo ">> Packages that have failed START"
    echo ${FAILEDPACKAGES}
    echo ">> Packages that have failed END"

    PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
    for packagemanifest in $(oc --kubeconfig=${KUBECONFIG_HUB} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
        for package in $(oc --kubeconfig=${KUBECONFIG_HUB} get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
            for pkg in ${FAILEDPACKAGES}; do
                echo $package | grep -qE $pkg
                MATCH=$?
                if [ ${MATCH} == 0 ]; then
                    echo
                    echo "Package: ${package}"
                    echo "DEBUG: skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}"
                    skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
                    if [[ ${?} != 0 ]]; then
                        retry=1
                        while [ ${retry} != 0 ]; do
                            echo "INFO: Failed Image Copy, retrying after 5 seconds..."
                            skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
                            if [[ ${?} == 0 ]]; then
                                retry=0
                            else
                                sleep 10
                                retry=$((retry + 1))
                            fi
                            if [ ${retry} == 12 ]; then
                                echo ">>>> ERROR: Retry limit reached to copy image ${package}"
                                exit 1
                            fi
                        done
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
        if [[ ${?} != 0 ]]; then
            retry=1
            while [ ${retry} != 0 ]; do
                echo "INFO: Failed Image Copy, retrying after 5 seconds..."
                skopeo copy docker://${image} docker://${DESTINATION_REGISTRY}/${image#*/} --all --authfile ${PULL_SECRET}
                if [[ ${?} == 0 ]]; then
                    retry=0
                else
                    sleep 10
                    retry=$((retry + 1))
                fi
                if [ ${retry} == 12 ]; then
                    echo ">>>> ERROR: Retry limit reached to copy image ${image}"
                    exit 1
                fi
            done
        fi
        sleep 1
    done
}

function mirror_certified() {
    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    export STORAGE_DRIVER=vfs
    sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######
    ## Load GPG keys to pull certified operator images
    echo ">>>> Loading GPG key to pull Certified Operators"
    curl -s -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv https://www.redhat.com/security/data/55A34A82.txt
    podman image trust set -f /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-isv registry.redhat.io/redhat/certified-operator-index
    # Check for credentials for OPM
    if [[ ${1} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    elif [[ ${1} == 'edgecluster' ]]; then
        TARGET_KUBECONFIG=${EDGE_KUBECONFIG}
        echo ">>>> Checking Source Registry: ${SOURCE_REGISTRY}"
        check_registry ${SOURCE_REGISTRY}
        echo ">>>> Checking Destination Registry: ${DESTINATION_REGISTRY}"
        check_registry ${DESTINATION_REGISTRY}
    fi

    echo ">>>> Podman Login into Source Registry: ${SOURCE_REGISTRY}"
    registry_login ${SOURCE_REGISTRY}
    echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
    registry_login ${DESTINATION_REGISTRY}

    if [ ! -f ~/.docker/config.json ]; then
        echo "INFO: missing ~/.docker/config.json config"
        echo "Creating file"
        unalias cp &>/dev/null || echo "Unaliased cp: Done!"
        mkdir -p ~/.docker/
        cp -rf ${PULL_SECRET} ~/.docker/config.json
    fi

    echo "Copy credentails for opm index"
    mkdir -p /var/run/user/0/containers
    cp -f /workspace/ztp/build/pull-secret.json /var/run/user/0/containers/auth.json

    echo ">>>> Mirror Certified OLM Operators"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Pull Secret: ${PULL_SECRET}"
    echo "Source Index: ${CERTIFIED_SOURCE_INDEX}"
    echo "Source Packages: ${CERTIFIED_SOURCE_PACKAGES}"
    echo "Destination Index: ${OLM_CERTIFIED_DESTINATION_INDEX}"
    echo "Destination Registry: ${DESTINATION_REGISTRY}"
    echo "Destination Namespace: ${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}"
    echo "Target Kubeconfig: ${TARGET_KUBECONFIG}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"

    # Empty log file
    >${OUTPUTDIR}/mirror.log

    # Certified Operators
    SALIDA=1

    retry=1
    while [ ${retry} != 0 ]; do
        # Mirror redhat-operator index image
        echo "DEBUG: opm index prune --from-index ${CERTIFIED_SOURCE_INDEX} --packages ${CERTIFIED_SOURCE_PACKAGES} --tag ${OLM_CERTIFIED_DESTINATION_INDEX}"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
        opm index prune --from-index ${CERTIFIED_SOURCE_INDEX} --packages ${CERTIFIED_SOURCE_PACKAGES} --tag ${OLM_CERTIFIED_DESTINATION_INDEX} >>${OUTPUTDIR}/mirror.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> Pruning index image finished: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            retry=0
        else
            echo ">>>> INFO: Failed pruning index image: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            echo ">>>> INFO: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Failed pruning index image: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    retry=1
    while [ ${retry} != 0 ]; do
        echo "DEBUG: GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_CERTIFIED_DESTINATION_INDEX} --authfile ${PULL_SECRET}"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
        GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_CERTIFIED_DESTINATION_INDEX} --authfile ${PULL_SECRET} >>${OUTPUTDIR}/mirror.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> Push index image finished: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            retry=0
        else
            echo ">>>> INFO: Failed pushing index image: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            echo ">>>> INFO: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Failed pushing index image: ${OLM_CERTIFIED_DESTINATION_INDEX}"
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    # Mirror redhat-operator packages
    echo ">>>> Trying to push OLM images to Internal Registry"
    echo "oc adm catalog mirror ${OLM_CERTIFIED_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100"
    oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_CERTIFIED_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100 >>${OUTPUTDIR}/mirror.log 2>&1

    cat ${OUTPUTDIR}/mirror.log | grep 'error:' >${OUTPUTDIR}/mirror-error.log

    # Patch to avoid issues on mirroring
    # In order to match both / and - in the package name we replace them by . that grep with regexp mode can understand
    FAILEDPACKAGES=$(cat ${OUTPUTDIR}/mirror-error.log | tr ": " "\n" | grep ${DESTINATION_REGISTRY} | sed "s/${DESTINATION_REGISTRY}//g" | sed "s#^/##g" | sed 's#-#.#g' | sed 's#olm/##g' | sed 's#/#.#g' | sort -u | xargs echo)

    echo ">> Packages that have failed START"
    echo ${FAILEDPACKAGES}
    echo ">> Packages that have failed END"

    CERTIFIED_PACKAGES_FORMATED=$(echo ${CERTIFIED_SOURCE_PACKAGES} | tr "," " ")
    for packagemanifest in $(oc --kubeconfig=${KUBECONFIG_HUB} get packagemanifest -n openshift-marketplace -o name ${CERTIFIED_PACKAGES_FORMATED}); do
        for package in $(oc --kubeconfig=${KUBECONFIG_HUB} get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
            for pkg in ${FAILEDPACKAGES}; do
                echo $package | grep -qE $pkg
                MATCH=$?
                if [ ${MATCH} == 0 ]; then
                    echo
                    echo "Package: ${package}"
                    echo "DEBUG: skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}"
                    skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
                    if [[ ${?} != 0 ]]; then
                        echo "INFO: Failed Image Copy, retrying after 5 seconds..."
                        sleep 10
                        skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
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
        if [ -z $CERTIFIED_SOURCE_PACKAGES ]; then
            echo ">>>> There are no certified operators to be mirrored"
        else
            mirror_certified 'hub'
        fi
    else
        echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
    fi
elif [[ ${1} == "edgecluster" ]]; then
    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    for edgecluster in ${ALLEDGECLUSTERS}; do
        # Get Edge-cluster Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${edgecluster}" ]]; then
            extract_kubeconfig ${edgecluster}
        else
            export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgecluster}"
        fi
        prepare_env 'edgecluster'
        create_cs 'edgecluster' ${edgecluster}
        trust_internal_registry 'hub'
        trust_internal_registry 'edgecluster' ${edgecluster}
        if ! ./verify_olm_sync.sh 'edgecluster'; then
            mirror 'edgecluster'
            if [ -z $CERTIFIED_SOURCE_PACKAGES ]; then
                echo ">>>> There are no certified operators to be mirrored"
            else
                mirror_certified 'edgecluster'
            fi
        else
            echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
        fi
    done
fi


# debug options
debug_status ended
echo "INFO: End of $PWD/$(basename -- "${BASH_SOURCE[0]}")"