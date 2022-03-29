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
    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    export STORAGE_DRIVER=vfs
    sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######


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

    echo "Copy credentails for opm index"
    mkdir -p /var/run/user/0/containers
    cp -f /workspace/ztp/build/pull-secret.json /var/run/user/0/containers/auth.json

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
      registry:
        imageURL: $DESTINATION_REGISTRY/$OCP_DESTINATION_REGISTRY_IMAGE_NS
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
    echo "oc-mirror --dir=${OUTPUTDIR} --max-per-registry=150 --config ${OUTPUTDIR}/oc-mirror-hub.yaml  docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --dest-skip-tls"
    oc-mirror --dir=${OUTPUTDIR} --max-per-registry=100 --config=${OUTPUTDIR}/oc-mirror-hub.yaml  docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --dest-skip-tls --skip-cleanup
    SALIDA=$?

    if [ ${SALIDA} -eq 0 ]; then
        echo ">>>> Mirroring with oc-mirror step finished"
    else
        echo ">>>> ERROR: Mirroring with oc-mirror failed"
        exit 1
    fi


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
