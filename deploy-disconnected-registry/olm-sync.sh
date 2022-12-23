#!/usr/bin/env bash

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

function prepare_env() {
    ## Load Env
    source ./common.sh ${1}
    export XDG_RUNTIME_DIR=/var/run/user/0
    mkdir -p $XDG_RUNTIME_DIR
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

function wait_for_mcp_ready() {
    # This function waits for the MCP to be ready
    # It will wait for the MCP to be ready for the given number of seconds
    # If the MCP is not ready after the given number of seconds, it will exit with an error
    if [[ $# -lt 3 ]]; then
        echo "Usage :"
        echo "wait_for_mcp_ready (kubeconfig) (edgecluster) (TIMEOUT)"
        exit 1
    fi

    export KUBECONF=${1}
    export CLUSTER=${2}
    export TIMEOUT=${3}

    echo ">>>> Waiting for ${CLUSTER} to be ready"
    TMC=$(oc --kubeconfig=${KUBECONF} get mcp master -o jsonpath={'.status.machineCount'})
    for i in $(seq 1 ${TIMEOUT}); do
        echo ">>>> Showing nodes in cluster: ${CLUSTER}"
        oc --kubeconfig=${KUBECONF} get nodes
        if [[ $(oc --kubeconfig=${KUBECONF} get mcp master -o jsonpath={'.status.readyMachineCount'}) -eq ${TMC} ]]; then
            echo ">>>> MCP ${CLUSTER} is ready"
            return 0
        fi
        sleep 20
        side_evict_error ${KUBECONF}
        echo ">>>>"
    done

    echo ">>>> MCP ${CLUSTER} is not ready after ${TIMEOUT} seconds"
    exit 1
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

    [ -d ~/.docker ] || mkdir  ~/.docker
    sleep 15
    echo ">>>> Copy pull secret to ~/.docker/config.json"
    mkdir -p ~/.docker
    cp -f ${PULL_SECRET} ~/.docker/config.json

    mkdir -p /var/run/user/0/containers
    cp -f ${PULL_SECRET} /var/run/user/0/containers/auth.json
    echo ">>>> Copy done!"

    echo ">>>> Mirror OLM Operators"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Pull Secret: ${PULL_SECRET}"
    echo "Destination Registry: ${DESTINATION_REGISTRY}"
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
    EXIT_CODE=1

    retry=1
    while [ ${retry} != 0 ]; do
        # Mirror using oc-mirror for Red Hat Operators and certified operators
        echo "DEBUG: oc-mirror --config ${OUTPUTDIR}/oc-mirror-config.yaml --max-per-registry 50 --ignore-history docker://${OC_MIRROR_DESTINATION_REGISTRY} --source-skip-tls --dest-skip-tls --skip-cleanup"

        echo ">>> The following operation might take a while... storing in ${OUTPUTDIR}/mirror-${1}.log"
	envsubst <${WORKDIR}/deploy-disconnected-registry/oc-mirror-config-${1}.yaml > ${OUTPUTDIR}/oc-mirror-config.yaml
        oc-mirror --config ${OUTPUTDIR}/oc-mirror-config.yaml \
		--max-per-registry 50 \
		--ignore-history \
		docker://${OC_MIRROR_DESTINATION_REGISTRY} \
		--source-skip-tls \
		--dest-skip-tls \
		--skip-cleanup | tee -a ${OUTPUTDIR}/mirror-${1}.log 2>&1
        EXIT_CODE=$?

        if [ ${EXIT_CODE} -eq 0 ]; then
            echo ">>>> Mirror olm (redhat operator and certified) finished."
            retry=0
        else
            echo ">>>> ERROR: Failed doing mirror (redhat operator and certified)."
            echo ">>>> ERROR: Retrying in 10 seconds"
            sleep 10
            retry=$((retry + 1))
        fi
        if [ ${retry} == 12 ]; then
            echo ">>>> ERROR: Doing the mirror of olm operators and certified."
            echo ">>>> ERROR: Retry limit reached"
            exit 1
        fi
    done

    if [[ ${1} == 'hub' ]]; then
      MANIFESTS_DIR=$OUTPUTDIR/manifests/
      mkdir -p $MANIFESTS_DIR

      cp ${WORKDIR}/deploy-disconnected-registry/oc-mirror-workspace/results-*/imageContentSourcePolicy.yaml ${MANIFESTS_DIR}/
      cp ${WORKDIR}/deploy-disconnected-registry/oc-mirror-workspace/results-*/catalogSource-redhat-operator-index.yaml ${MANIFESTS_DIR}/catalogsource-redhat-operators.yaml
      sed -i "s/name: redhat-operator-index/name: redhat-operators/g" ${MANIFESTS_DIR}/catalogsource-redhat-operators.yaml
      cp ${WORKDIR}/deploy-disconnected-registry/oc-mirror-workspace/results-*/catalogSource-certified-operator-index.yaml ${MANIFESTS_DIR}/catalogsource-certified-operators.yaml
      sed -i "s/name: certified-operator-index/name: certified-operators/g"  ${MANIFESTS_DIR}/catalogsource-certified-operators.yaml

      oc --kubeconfig=${TARGET_KUBECONFIG} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
      oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${MANIFESTS_DIR}
      wait_for_mcp_ready ${TARGET_KUBECONFIG} 'hub' 240
    fi
}


if [[ ${1} == 'hub' ]]; then
    prepare_env 'hub'
    trust_internal_registry 'hub'
    if ! ./verify_olm_sync.sh 'hub'; then
        mirror 'hub'
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
        trust_internal_registry 'hub'
        trust_internal_registry 'edgecluster' ${edgecluster}
        if ! ./verify_olm_sync.sh 'edgecluster'; then
            mirror 'edgecluster'
        else
            echo ">>>> This step to mirror olm is not neccesary, everything looks ready"
        fi
    done
fi
