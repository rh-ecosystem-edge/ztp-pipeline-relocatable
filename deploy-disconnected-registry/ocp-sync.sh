#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting EDGE_KUBECONFIG: ${EDGE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $edgecluster secret/$edgecluster-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

function mirror_ocp() {

    if [[ ${1} == 'hub' ]]; then
        TARGET_KUBECONFIG=${KUBECONFIG_HUB}
        cluster=${2}
    elif [[ ${1} == 'edgecluster' ]]; then
        TARGET_KUBECONFIG=${EDGE_KUBECONFIG}
        cluster=${2}
    fi

    echo ">>>> Mirror OpenShift Version"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Pull Secret: ${PULL_SECRET}"
    echo "OCP Release Image: ${OPENSHIFT_RELEASE_IMAGE}"
    echo "Destination Index: ${OCP_DESTINATION_INDEX}"
    echo "Destination Registry: ${DESTINATION_REGISTRY}"
    echo "Destination Namespace: ${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}"
    echo "Target Kubeconfig: ${TARGET_KUBECONFIG}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo

    if [[ ${CUSTOM_REGISTRY} == "true" ]]; then
        echo "Checking Private registry creds"
        if [[ ! $(podman login ${LOCAL_REG} --authfile ${PULL_SECRET}) ]]; then
            echo "ERROR: Failed to login to ${LOCAL_REG}, please check Pull Secret"
            exit 1
        else
            echo "Login successfully to ${LOCAL_REG}"
        fi
    fi
    #######

    # Empty log file
    >${OUTPUTDIR}/mirror-ocp.log
    SALIDA=1

    retry=1
    while [ ${retry} != 0 ]; do
        # Mirror ocp release with retry strategy
        echo DEBUG: "oc --kubeconfig=${TARGET_KUBECONFIG} adm release mirror -a ${PULL_SECRET} --from=${OPENSHIFT_RELEASE_IMAGE} --to-release-image=${OCP_DESTINATION_INDEX} --to=${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}"
        oc --kubeconfig=${TARGET_KUBECONFIG} adm release mirror -a ${PULL_SECRET} --from="${OPENSHIFT_RELEASE_IMAGE}" --to-release-image="${OCP_DESTINATION_INDEX}" --to="${DESTINATION_REGISTRY}/${OCP_DESTINATION_REGISTRY_IMAGE_NS}" >>${OUTPUTDIR}/mirror-ocp.log 2>&1
        SALIDA=$?

        if [ ${SALIDA} -eq 0 ]; then
            echo ">>>> OCP release image mirror step finished: ${OPENSHIFT_RELEASE_IMAGE}"
            retry=0
        else
            echo ">>>> INFO: Failed mirroring the release image: ${OPENSHIFT_RELEASE_IMAGE}"
            echo ">>>> INFO: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Mirroring the release image: ${OPENSHIFT_RELEASE_IMAGE}"
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done
}

if [[ ${1} == 'hub' ]]; then
    # Loading variables here in purpose
    source ./common.sh 'hub'
    trust_internal_registry 'hub'

    if ! ./verify_ocp_sync.sh 'hub'; then

        if [[ ${CUSTOM_REGISTRY} == "false" ]]; then
            oc create namespace ${REGISTRY} -o yaml --dry-run=client | oc apply -f -
            # TODO: commented out the next line seems not needed
            # export REGISTRY_NAME="$(oc get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
        fi
        registry_login ${DESTINATION_REGISTRY}
        mirror_ocp 'hub' 'hub'
    else
        echo ">>>> This step to mirror ocp is not neccesary, everything looks ready: ${1}"
    fi

elif [[ ${1} == 'edgecluster' ]]; then
    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    for edgecluster in ${ALLEDGECLUSTERS}; do
        # Get Edge-cluster Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${edgecluster}" ]]; then
            extract_kubeconfig ${edgecluster}
        else
            export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgecluster}"
            echo "Exporting EDGE_KUBECONFIG: ${EDGE_KUBECONFIG}"
        fi

        # Loading variables here in purpose
        source ./common.sh 'edgecluster'
        # Here we need to trust on both registries
        trust_internal_registry 'hub'
        trust_internal_registry 'edgecluster' ${edgecluster}

        if ! ./verify_ocp_sync.sh 'edgecluster'; then

            oc --kubeconfig=${EDGE_KUBECONFIG} create namespace ${REGISTRY} -o yaml --dry-run=client | oc apply -f -

            ## Logging into the Source and Destination registries
            ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
            ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS}
            ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
            ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS}
            mirror_ocp 'edgecluster' ${edgecluster}
        else
            echo ">>>> This step to mirror ocp is not neccesary, everything looks ready: ${1}"
        fi
    done
fi
