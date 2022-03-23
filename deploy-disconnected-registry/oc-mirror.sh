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
    for binary in {opm,oc,skopeo,podman,oc-mirror}; do
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

   # echo "Copy credentails for opm index"
   # mkdir -p /var/run/user/0/containers
   # cp -f /workspace/ztp/build/pull-secret.json /var/run/user/0/containers/auth.json

    echo ">>>> Mirror OCP and OLM Operators and images"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Pull Secret: ${PULL_SECRET}"
    echo "Source Index: ${SOURCE_INDEX}"
    echo "Source Packages: ${PACKAGES_FORMATED}"
    echo "Destination Registry: ${DESTINATION_REGISTRY}"
    echo "OCP Release and release full: ${OCP_RELEASE} --> ${OCP_RELEASE_FULL}"
    echo "OCP_DESTINATION_REGISTRY_IMAGE_NS: ${OCP_DESTINATION_REGISTRY_IMAGE_NS}"
    echo "Target Kubeconfig: ${TARGET_KUBECONFIG}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"

    # Create the yaml file
    cat <<EOF > ${OUTPUTDIR}/oc-mirror-hub.yaml
    apiVersion: mirror.openshift.io/v1alpha2
    kind: ImageSetConfiguration
    storageConfig:
    apiVersion: mirror.openshift.io/v1alpha2
      registry:
        imageURL: $DESTINATION_REGISTRY/$OCP_DESTINATION_REGISTRY_IMAGE_NS
    apiVersion: mirror.openshift.io/v1alpha2
        skipTLS: true
    mirror:
      ocp: # OCP Releases we want to mirror
        channels:
          - name: stable-$OCP_RELEASE
            minVersion: $OCP_RELEASE_FULL
            maxVersion: $OCP_RELEASE_FULL
      operators:
        - catalog: registry.redhat.io/redhat/redhat-operator-index:v$OCP_RELEASE
          headsOnly: false
          packages:
EOF
for PACKAGE in ${PACKAGES_FORMATED}; do
  echo "            - name: $PACKAGE" >> ${OUTPUTDIR}/oc-mirror-hub.yaml
done


    echo "Launch the oc-mirror command to mirror ocp and olm operators and images"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "oc-mirror --dir=${OUTPUTDIR} --config ${OUTPUTDIR}/oc-mirror-hub.yaml  docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --dest-skip-tls"


    >${OUTPUTDIR}/mirror.log
    SALIDA=1

    retry=1
    while [ ${retry} != 0 ]; do
        # Mirror redhat-operator index image
        echo "DEBUG: opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
        oc-mirror --dir=${OUTPUTDIR} --config=${OUTPUTDIR}/oc-mirror-hub.yaml  docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --dest-skip-tls >>${OUTPUTDIR}/mirror.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> Mirroring step finished"
            retry=0
        else
            echo ">>>> ERROR: Mirroring"
            echo ">>>> ERROR: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Mirroring "
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    #export STORAGE_DRIVER=vfs
    #sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######

    # Empty log file
    #>${OUTPUTDIR}/mirror.log
    #SALIDA=1
    #
    #retry=1
    #while [ ${retry} != 0 ]; do
    #    # Mirror redhat-operator index image
    #    echo "DEBUG: opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX}"
    #
    #    echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
    #    opm index prune --from-index ${SOURCE_INDEX} --packages ${SOURCE_PACKAGES} --tag ${OLM_DESTINATION_INDEX} >>${OUTPUTDIR}/mirror.log 2>&1
    #    SALIDA=$?
    #
    #    if [ ${SALIDA} -eq 0 ]; then
    #        echo ">>>> Pruning index image finished: ${OLM_DESTINATION_INDEX}"
    #        retry=0
    #    else
    #        echo ">>>> ERROR: Pruning index image: ${OLM_DESTINATION_INDEX}"
    #        echo ">>>> ERROR: Retrying in 10 seconds"
    #        sleep 10
    #        retry=$((retry + 1))
    #    fi
    #    if [ ${retry} == 12 ]; then
    #        echo ">>>> ERROR: Pruning index image: ${OLM_DESTINATION_INDEX}"
    #        echo ">>>> ERROR: Retry limit reached"
    #        exit 1
    #    fi
    #done
    #
    #retry=1
    #while [ ${retry} != 0 ]; do
    #    echo "DEBUG: GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET}"
    #
    #    echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror.log"
    #    GODEBUG=x509ignoreCN=0 podman push --tls-verify=false ${OLM_DESTINATION_INDEX} --authfile ${PULL_SECRET} >>${OUTPUTDIR}/mirror.log 2>&1
    #    SALIDA=$?
    #
    #    if [ ${SALIDA} -eq 0 ]; then
    #        echo ">>>> Push index image finished: ${OLM_DESTINATION_INDEX}"
    #        retry=0
    #    else
    #        echo ">>>> ERROR: Pushing index image: ${OLM_DESTINATION_INDEX}"
    #        echo ">>>> ERROR: Retrying in 10 seconds"
    #        sleep 10
    #        retry=$((retry + 1))
    #    fi
    #    if [ ${retry} == 12 ]; then
    #        echo ">>>> ERROR: Pushing index image: ${OLM_DESTINATION_INDEX}"
    #        echo ">>>> ERROR: Retry limit reached"
    #        exit 1
    #    fi
    #done
    #
    ## Mirror redhat-operator packages
    #echo ">>>> Trying to push OLM images to Internal Registry"
    #echo "DEBUG: GODEBUG=x509ignoreCN=0 oc adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET}"
    #GODEBUG=x509ignoreCN=0 oc --kubeconfig=${TARGET_KUBECONFIG} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --max-per-registry=100 >>${OUTPUTDIR}/mirror.log 2>&1
    #
    #cat ${OUTPUTDIR}/mirror.log | grep 'error:' >${OUTPUTDIR}/mirror-error.log
    #
    ## Patch to avoid issues on mirroring
    ## In order to match both / and - in the package name we replace them by . that grep with regexp mode can understand
    #FAILEDPACKAGES=$(cat ${OUTPUTDIR}/mirror-error.log | tr ": " "\n" | grep ${DESTINATION_REGISTRY} | sed "s/${DESTINATION_REGISTRY}//g" | sed "s#^/##g" | sed 's#-#.#g' | sed 's#olm/##g' | sed 's#/#.#g' | sort -u | xargs echo)
    #
    #echo ">> Packages that have failed START"
    #echo ${FAILEDPACKAGES}
    #echo ">> Packages that have failed END"
    #
    #PACKAGES_FORMATED=$(echo ${SOURCE_PACKAGES} | tr "," " ")
    #for packagemanifest in $(oc --kubeconfig=${KUBECONFIG_HUB} get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
    #    for package in $(oc --kubeconfig=${KUBECONFIG_HUB} get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
    #        for pkg in ${FAILEDPACKAGES}; do
    #            echo $package | grep -qE $pkg
    #            MATCH=$?
    #            if [ ${MATCH} == 0 ]; then
    #                echo
    #                echo "Package: ${package}"
    #                echo "DEBUG: skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}"
    #                skopeo copy --remove-signatures docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
    #                if [[ ${?} != 0 ]]; then
    #                    echo "Error on Image Copy, retrying after 5 seconds..."
    #                    sleep 10
    #                    skopeo copy docker://${package} docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --all --authfile ${PULL_SECRET}
    #                fi
    #                sleep 1
    #            fi
    #        done
    #    done
    #done

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
    #create_cs 'hub'
    trust_internal_registry 'hub'
    mirror 'hub'

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
        #create_cs 'spoke' ${spoke}
        trust_internal_registry 'hub'
        trust_internal_registry 'spoke' ${spoke}
        mirror 'spoke'
    done
fi
