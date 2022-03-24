#!/usr/bin/env bash

#set -o errexit
set -o pipefail
set -o nounset
set -m

function copy_files() {
    src_files=${1}
    dst_node=${2}
    dst_folder=${3}

    if [[ -z ${src_files} ]]; then
        echo "Source files variable empty: ${src_files[@]}"
        exit 1
    fi

    if [[ -z ${dst_node} ]]; then
        echo "Destination IP variable empty: ${dst_node}"
        exit 1
    fi

    if [[ -z ${dst_folder} ]]; then
        echo "Destination folder variable empty: ${dst_folder}"
        exit 1
    fi

    echo "Copying source files: ${src_files[@]} to Node ${dst_node}"
    ${SCP_COMMAND} -i ${RSA_KEY_FILE} ${src_files[@]} core@${dst_node}:${dst_folder}
}

function grab_master_ext_ips() {
    spoke=${1}
    spokeitem=${2}

    ## Grab 1 master and 1 IP
    agent=$(oc --kubeconfig=${KUBECONFIG_HUB} get agents -n ${spoke} --no-headers -o name | head -1)
    export SPOKE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${spoke} ${agent} -o jsonpath={.spec.hostname})
    master=${SPOKE_NODE_NAME##*-}
    export MAC_EXT_DHCP=$(yq e ".spokes[$spokeitem].${spoke}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
    ## HAY QUE PROBAR ESTO
    SPOKE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get ${agent} -n ${spoke} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
    export SPOKE_NODE_IP=${SPOKE_NODE_IP_RAW%%/*}
}

function check_connectivity() {
    IP=${1}
    echo ">> Checking connectivity against: ${IP}"

    if [[ -z ${IP} ]]; then
        echo "ERROR: Variable \${IP} empty, this could means that the ARP does not match with the MAC address provided in the Spoke File ${SPOKES_FILE}"
        exit 1
    fi

    ping ${IP} -c4 -W1 2>&1 >/dev/null
    RC=${?}

    if [[ ${RC} -eq 0 ]]; then
        export CHECKED_IP='available'
        echo "Connectivity validated!"
    else
        export CHECKED_IP='unreachable'
        echo "ERROR: IP ${IP} Unreachable!"
        exit 1
    fi
    echo
}

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    echo ">>>> Extracting all Kubeconfig from Hub cluster"
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]]; then
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting SPOKE_KUBECONFIG: ${SPOKE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${SPOKE_KUBECONFIG}
}

function icsp_mutate() {
    echo ">>>> Mutating Registry for: ${spoke}"
    MAP=${1}
    DST_REG=${2}
    SPOKE=${3}
    HUB_REG_ROUTE="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
    export SPOKE_MAPPING_FILE="${MAP%%.*}-${spoke}.txt"
    sed "s/${HUB_REG_ROUTE}/${DST_REG}/g" ${MAP} | tee "${MAP%%.*}-${spoke}.txt"
}

function generate_mapping() {
    echo ">>>> Loading Common file"
    ## Not fully sure but we create the base mapping file using the hub definition and then, when it makes sense we mutate it changing the destination registry
    source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'

    ####### WORKAROUND: Newer versions of podman/buildah try to set overlayfs mount options when
    ####### using the vfs driver, and this causes errors.
    export STORAGE_DRIVER=vfs
    sed -i '/^mountopt =.*/d' /etc/containers/storage.conf
    #######
    echo ">>>> Podman Login into Source Registry: ${SOURCE_REGISTRY}"
    ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
    ${PODMAN_LOGIN_CMD} ${SOURCE_REGISTRY} -u ${REG_US} -p ${REG_PASS}
    echo ">>>> Podman Login into Destination Registry: ${DESTINATION_REGISTRY}"
    ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
    ${PODMAN_LOGIN_CMD} ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS}

    echo ">>>> Creating Mirror Manifests with oc-mirror"
    echo "DEBUG: oc-mirror --dir=${OUTPUTDIR} --max-per-registry=150 docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --config=${OUTPUTDIR}/oc-mirror-hub.yaml --dry-run"
    oc-mirror --dir=${OUTPUTDIR} --max-per-registry=150 docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --config=${OUTPUTDIR}/oc-mirror-hub.yaml --dry-run --dest-skip-tls
    #echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests"
    #GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests
    echo ">>>> Copying mapping file to ${OUTPUTDIR}/mapping.txt"
    unalias cp &>/dev/null || echo "Unaliased cp: Done!"
    cp -f ${OUTPUTDIR}/olm-manifests/mapping.txt ${OUTPUTDIR}/mapping.txt
}

function recover_mapping() {
    MAP_FILENAME='mapping.txt'
    echo ">>>> Finding Map file for the Mirror Sync"
    if [[ ! -f "${OUTPUTDIR}/${MAP_FILENAME}" ]]; then
        echo ">>>> No mapping file found for the Mirror Sync"
        MAP="${OUTPUTDIR}/${MAP_FILENAME}"
        find ${OUTPUTDIR} -name "${MAP_FILENAME}*" -exec cp {} ${MAP} \;
        if [[ ! -f ${MAP} ]]; then
            generate_mapping
        fi
    fi
}

function gen_header() {
    cat <<EOF >${ICSP_OUTFILE}
---
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  labels:
    operators.openshift.org/catalog: "true"
  name: ztpfw-${cluster}
spec:
  repositoryDigestMirrors:
EOF
}

function add_icsp_entry() {
    ## Add entry for every image on the packageManifests
    SRC_IMG=${1}
    DST_IMG=${2}

    cat <<EOF >>${ICSP_OUTFILE}
  - mirrors:
    - ${DST_IMG}
    source: ${SRC_IMG}
EOF

}

function icsp_maker() {
    # This function generated the ICSP for the current spoke
    if [[ $# -lt 3 ]]; then
        echo "Usage :"
        echo "  icsp_maker (MAPPING FILE) (ICSP DESTINATION FILE) hub|<spoke>"
        exit 1
    fi

    export MAP_FILE=${1}
    export ICSP_OUTFILE=${2}
    export cluster=${3}

    gen_header ${ICSP_OUTFILE} ${cluster}

    while read entry; do
        RAW_SRC=${entry%%=*}
        RAW_DST=${entry##*=}
        SRC_IMG="${RAW_SRC%%@*}"
        DST_IMG="${RAW_DST%%:*}"
        add_icsp_entry ${SRC_IMG} ${DST_IMG}
    done <${MAP_FILE}
}

function side_evict_error() {

    KUBEC=${1}
    echo ">> Looking for eviction errors"
    pattern='SchedulingDisabled'

    conflicting_node="$(oc --kubeconfig=${KUBEC} get node --no-headers | grep ${pattern} | cut -f1 -d\ )"

    if [[ -z ${conflicting_node} ]]; then
        echo "No masters on ${pattern}"
    else
        conflicting_daemon_pod=$(oc --kubeconfig=${KUBEC} get pod -n openshift-machine-config-operator -o wide --no-headers | grep daemon | grep ${conflicting_node} | cut -f1 -d\ )
        log_entry="$(oc --kubeconfig=${KUBEC} logs -n openshift-machine-config-operator ${conflicting_daemon_pod} -c machine-config-daemon | grep drain.go | grep evicting | tail -1 | grep pods)"

        if [[ -z ${log_entry} ]]; then
            echo "No Conflicting LogEntry on ${conflicting_daemon_pod}"
        else
            echo ">> Conflicting LogEntry Found!!"
            pod=$(echo ${log_entry##*pods/} | cut -d\" -f2)
            conflicting_ns=$(oc --kubeconfig=${KUBEC} get pod -A | grep ${pod} | cut -f1 -d\ )

            echo ">> Clean Eviction triggered info: "
            echo NODE: ${conflicting_node}
            echo DAEMON: ${conflicting_daemon_pod}
            echo NS: ${conflicting_ns}
            echo LOG: ${log_entry}
            echo POD: ${pod}

            oc --kubeconfig=${KUBEC} delete pod -n ${conflicting_ns} ${pod}
        fi
    fi
}

function wait_for_mcp_ready() {
    # This function waits for the MCP to be ready
    # It will wait for the MCP to be ready for the given number of seconds
    # If the MCP is not ready after the given number of seconds, it will exit with an error
    if [[ $# -lt 3 ]]; then
        echo "Usage :"
        echo "wait_for_mcp_ready (kubeconfig) (spoke) (TIMEOUT)"
        exit 1
    fi

    export KUBECONF=${1}
    export CLUSTER=${2}
    export TIMEOUT=${3}

    echo ">>>> Waiting for ${CLUSTER} to be ready"
    for i in $(seq 1 ${TIMEOUT}); do
        echo ">>>> Showing nodes in cluster: ${CLUSTER}"
        oc --kubeconfig=${KUBECONF} get nodes
        if [[ $(oc --kubeconfig=${KUBECONF} get mcp master -o jsonpath={'.status.readyMachineCount'}) -eq 3 ]]; then
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

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh
export MAP_FILENAME='mapping.txt'

if [[ ${1} == 'hub' ]]; then
    # Validation
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 hub|spoke (STAGE (mandatory on spoke MODE))"
        exit 1
    fi

    echo ">>>> Creating ICSP for: Hub"
    source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'
    # Recover mapping calls the source over the common.sh file under deploy-disconnected
    trust_internal_registry 'hub'
    recover_mapping
    icsp_maker ${OUTPUTDIR}/${MAP_FILENAME} ${OUTPUTDIR}/icsp-hub.yaml 'hub'
    oc --kubeconfig=${KUBECONFIG_HUB} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
    if [[ ! -f ${OUTPUTDIR}/catalogsource-hub.yaml ]]; then
        echo "CatalogSource File does not exists, generating a new one..."
        create_cs 'hub'
    fi
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${OUTPUTDIR}/catalogsource-hub.yaml
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${OUTPUTDIR}/icsp-hub.yaml
    wait_for_mcp_ready ${KUBECONFIG_HUB} 'hub' 240

elif [[ ${1} == 'spoke' ]]; then
    # Validation
    if [[ $# -lt 2 ]]; then
        echo "Usage :"
        echo "  $0 hub|spoke (STAGE (mandatory on spoke MODE))"
        exit 1
    fi

    # STAGE is the value to reflect which step are you in
    #    if you didn't synced from Hub to Spoke you need to put 'pre'
    #    if you already synced from Hub to Spoke you need to put 'post'
    STAGE=${2}

    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi
    _index=0
    for spoke in ${ALLSPOKES}; do
        # Logic
        # WC == 2 == SKIP / WC == 1 == Create ICSP
        if [[ ${STAGE} == 'pre' ]]; then
            ### WARNING: yes is 'hub' mode the first time you wanna deploy the CatalogSources because at this point we dont have Spoke API yet, so becareful changing this flow.
            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'

            # Get Spoke Kubeconfig
            if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
                extract_kubeconfig ${spoke}
            else
                export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
            fi

            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'
            trust_internal_registry 'hub'
            recover_mapping

            if [[ ! -f ${OUTPUTDIR}/catalogsource-hub.yaml ]]; then
                echo "CatalogSource Hub File does not exists, generating a new one..."
                create_cs 'hub'
            fi

            if [[ ! -f ${OUTPUTDIR}/icsp-hub.yaml ]]; then
                echo "ICSP Hub File does not exists, generating a new one..."
                icsp_maker ${OUTPUTDIR}/${MAP_FILENAME} ${OUTPUTDIR}/icsp-hub.yaml 'hub'
            fi
            recover_spoke_rsa ${spoke}

            # In this stage the spoke's registry does not exist, so we need to trust the Hub's ingress cert
            # Check API
            echo ">> Checking spoke API: ${STAGE}"
            echo ">> Kubeconfig: ${SPOKE_KUBECONFIG}"
            RCAPI=$(oc --kubeconfig=${SPOKE_KUBECONFIG} get nodes)
            # If not API
            if [[ -z ${RCAPI} ]]; then
                # Grab SPOKE IP
                grab_master_ext_ips ${spoke} ${_index}
                check_connectivity "${SPOKE_NODE_IP}"
                # Execute commands and Copy files
                ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "mkdir -p ~/manifests ~/.kube"
                copy_files "${SPOKE_KUBECONFIG}" "${SPOKE_NODE_IP}" "./.kube/config"
                copy_files "${OUTPUTDIR}/catalogsource-hub.yaml" "${SPOKE_NODE_IP}" "./manifests/catalogsource-hub.yaml"
                copy_files "${OUTPUTDIR}/icsp-hub.yaml" "${SPOKE_NODE_IP}" "./manifests/icsp-hub.yaml"
                # Check ICSP
                RCICSP=$(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} "oc get ImageContentSourcePolicy ztpfw-hub | wc -l || true")
                OC_COMMAND="${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${SPOKE_NODE_IP} oc"
                MANIFESTS_PATH='manifests'
            else
                RCICSP=$(oc --kubeconfig=${SPOKE_KUBECONFIG} get ImageContentSourcePolicy ztpfw-${spoke} | wc -l || true)
                OC_COMMAND="oc --kubeconfig=${SPOKE_KUBECONFIG}"
                MANIFESTS_PATH="${OUTPUTDIR}"
            fi

            if [[ ${RCICSP} -eq 2 ]]; then
                echo "Skipping ICSP creation as it already exists"
            else
                # Spoke Sync from the Hub cluster as a Source
                echo ">>>> Deploying ICSP for: ${spoke} using the Hub as a source"
                ${OC_COMMAND} apply -f ${MANIFESTS_PATH}/catalogsource-hub.yaml
                ${OC_COMMAND} apply -f ${MANIFESTS_PATH}/icsp-hub.yaml
            fi
        elif [[ ${STAGE} == 'post' ]]; then
            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'spoke'

            # Get Spoke Kubeconfig
            if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
                extract_kubeconfig ${spoke}
            else
                export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
            fi

            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'
            trust_internal_registry 'spoke' ${spoke}
            if [[ ! -f ${OUTPUTDIR}/catalogsource-${spoke}.yaml ]]; then
                echo "CatalogSource File does not exists, generating a new one..."
                create_cs 'spoke' ${spoke}
            fi
            recover_mapping
            recover_spoke_rsa ${spoke}

            RCICSP=$(oc --kubeconfig=${SPOKE_KUBECONFIG} get ImageContentSourcePolicy ztpfw-${spoke} | wc -l || true)
            if [[ ${RCICSP} -eq 2 ]]; then
                echo ">>>> Waiting for old stuff deletion..."
            else
                echo ">>>> Creating ICSP for: ${spoke}"
                # Use the Spoke's registry as a source
                source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'spoke'
                icsp_mutate ${OUTPUTDIR}/${MAP_FILENAME} ${DESTINATION_REGISTRY} ${spoke}
                icsp_maker ${SPOKE_MAPPING_FILE} ${OUTPUTDIR}/icsp-${spoke}.yaml ${spoke}

                # Clean Old stuff
                oc --kubeconfig=${SPOKE_KUBECONFIG} delete -f ${OUTPUTDIR}/catalogsource-hub.yaml || echo "CatalogSoruce already deleted!"
                oc --kubeconfig=${SPOKE_KUBECONFIG} delete -f ${OUTPUTDIR}/icsp-hub.yaml || echo "ICSP already deleted!"

                echo ">>>> Waiting for old stuff deletion..."
                sleep 20

                # Deploy New ICSP + CS
                oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-${spoke}.yaml
                oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f ${OUTPUTDIR}/icsp-${spoke}.yaml

                wait_for_mcp_ready ${SPOKE_KUBECONFIG} ${spoke} 120
            fi
        fi
        _index=$((_index + 1))
    done
fi
