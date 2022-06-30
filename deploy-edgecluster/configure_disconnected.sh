#!/usr/bin/env bash

#set -o errexit
set -o pipefail
set -o nounset
set -m


debug_status starting


function copy_files() {
    src_files=${1}
    dst_node=${2}
    dst_folder=${3}

    if [[ -z ${src_files} ]]; then
        echo "Source files variable empty:" "${src_files[@]}"
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

    echo "Copying source files:" "${src_files[@]}" "to Node ${dst_node}"
    ${SCP_COMMAND} -i ${RSA_KEY_FILE} "${src_files[@]}" core@${dst_node}:${dst_folder}
}

function grab_master_ext_ips() {
    edgecluster=${1}
    edgeclusteritem=${2}

    ## Grab 1 master and 1 IP
    agent=$(oc --kubeconfig=${KUBECONFIG_HUB} get agents -n ${edgecluster} --no-headers -o name | head -1)
    export EDGE_NODE_NAME=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${edgecluster} ${agent} -o jsonpath={.spec.hostname})
    master=${EDGE_NODE_NAME##*-}
    export MAC_EXT_DHCP=$(yq e ".edgeclusters[$edgeclusteritem].${edgecluster}.master${master}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})
    ## HAY QUE PROBAR ESTO
    EDGE_NODE_IP_RAW=$(oc --kubeconfig=${KUBECONFIG_HUB} get ${agent} -n ${edgecluster} --no-headers -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${MAC_EXT_DHCP%%/*}\")].ipV4Addresses[0]}")
    export EDGE_NODE_IP=${EDGE_NODE_IP_RAW%%/*}
}

function check_connectivity() {
    IP=${1}
    echo ">> Checking connectivity against: ${IP}"

    if [[ -z ${IP} ]]; then
        echo "ERROR: Variable \${IP} empty, this could means that the ARP does not match with the MAC address provided in the Edge-cluster File ${EDGECLUSTERS_FILE}"
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

    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting EDGE_KUBECONFIG: ${EDGE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $edgecluster $edgecluster-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${EDGE_KUBECONFIG}
}

function icsp_mutate() {
    echo ">>>> Mutating Registry for: ${edgecluster}"
    MAP=${1}
    DST_REG=${2}
    EDGE=${3}
    HUB_REG_ROUTE="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
    export EDGE_MAPPING_FILE="${MAP%%.*}-${edgecluster}.txt"
    sed "s/${HUB_REG_ROUTE}/${DST_REG}/g" ${MAP} | tee "${MAP%%.*}-${edgecluster}.txt"
}

function generate_mapping() {
    echo ">>>> Loading Common file"
    ## Not fully sure but we create the base mapping file using the hub definition and then, when it makes sense we mutate it changing the destination registry
    source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'
    echo ">>>> Creating OLM Manifests"
    echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests"
    GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests

    # Check if certified OLM operators required and if so add them to the mapping
    if [ -z $CERTIFIED_SOURCE_PACKAGES ]; then
        echo ">>>> There are no certified operators to be mirrored"
    else
        echo ">>>> Creating Certified OLM Manifests"
        echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-manifests"
        GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${OLM_CERTIFIED_DESTINATION_INDEX} ${DESTINATION_REGISTRY}/${OLM_CERTIFIED_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${OUTPUTDIR}/olm-certified-manifests
        # Merge additional certified olm mapping with the redhat olm in order to create just one icsp object with all the images
        cat ${OUTPUTDIR}/olm-certified-manifests/mapping.txt >>${OUTPUTDIR}/olm-manifests/mapping.txt
    fi
    echo ">>>> Copying mapping file to ${OUTPUTDIR}/mapping.txt"
    unalias cp &>/dev/null || echo "Unaliased cp: Done!"
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
    # This function generated the ICSP for the current edgecluster
    if [[ $# -lt 3 ]]; then
        echo "Usage :"
        echo "  icsp_maker (MAPPING FILE) (ICSP DESTINATION FILE) hub|<edgecluster>"
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
        DST_IMG="${RAW_DST}"
        add_icsp_entry ${SRC_IMG} ${DST_IMG}
    done <${MAP_FILE}
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

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh
export MAP_FILENAME='mapping.txt'

if [[ ${1} == 'hub' ]]; then
    # Validation
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 hub|edgecluster (STAGE (mandatory on edgecluster MODE))"
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

elif [[ ${1} == 'edgecluster' ]]; then
    # Validation
    if [[ $# -lt 2 ]]; then
        echo "Usage :"
        echo "  $0 hub|edgecluster (STAGE (mandatory on edgecluster MODE))"
        exit 1
    fi

    # STAGE is the value to reflect which step are you in
    #    if you didn't synced from Hub to Edge-cluster you need to put 'pre'
    #    if you already synced from Hub to Edge-cluster you need to put 'post'
    STAGE=${2}

    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi
    _index=0
    for edgecluster in ${ALLEDGECLUSTERS}; do
        # Logic
        # WC == 2 == SKIP / WC == 1 == Create ICSP
        if [[ ${STAGE} == 'pre' ]]; then
            ### WARNING: yes is 'hub' mode the first time you wanna deploy the CatalogSources because at this point we dont have Edge-cluster API yet, so becareful changing this flow.
            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'

            # Get Edge-cluster Kubeconfig
            if [[ ! -f "${OUTPUTDIR}/kubeconfig-${edgecluster}" ]]; then
                extract_kubeconfig ${edgecluster}
            else
                export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgecluster}"
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
            recover_edgecluster_rsa ${edgecluster}

            # In this stage the edgecluster's registry does not exist, so we need to trust the Hub's ingress cert
            # Check API
            echo ">> Checking edgecluster API: ${STAGE}"
            echo ">> Kubeconfig: ${EDGE_KUBECONFIG}"
            RCAPI=$(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes)
            # If not API
            if [[ -z ${RCAPI} ]]; then
                # Grab EDGE IP
                grab_master_ext_ips ${edgecluster} ${_index}
                check_connectivity "${EDGE_NODE_IP}"
                # Execute commands and Copy files
                ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "mkdir -p ~/manifests ~/.kube"
                copy_files "${EDGE_KUBECONFIG}" "${EDGE_NODE_IP}" "./.kube/config"
                copy_files "${OUTPUTDIR}/catalogsource-hub.yaml" "${EDGE_NODE_IP}" "./manifests/catalogsource-hub.yaml"
                copy_files "${OUTPUTDIR}/icsp-hub.yaml" "${EDGE_NODE_IP}" "./manifests/icsp-hub.yaml"
                # Check ICSP
                RCICSP=$(${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "oc get ImageContentSourcePolicy ztpfw-hub | wc -l || true")
                OC_COMMAND="${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} oc"
                MANIFESTS_PATH='manifests'
            else
                RCICSP=$(oc --kubeconfig=${EDGE_KUBECONFIG} get ImageContentSourcePolicy ztpfw-${edgecluster} | wc -l || true)
                OC_COMMAND="oc --kubeconfig=${EDGE_KUBECONFIG}"
                MANIFESTS_PATH="${OUTPUTDIR}"
            fi

            if [[ ${RCICSP} -eq 2 ]]; then
                echo "Skipping ICSP creation as it already exists"
            else
                # Edge-cluster Sync from the Hub cluster as a Source
                echo ">>>> Deploying ICSP for: ${edgecluster} using the Hub as a source"
                ${OC_COMMAND} apply -f ${MANIFESTS_PATH}/catalogsource-hub.yaml
                ${OC_COMMAND} apply -f ${MANIFESTS_PATH}/icsp-hub.yaml
            fi
        elif [[ ${STAGE} == 'post' ]]; then
            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'edgecluster'

            # Get Edge-cluster Kubeconfig
            if [[ ! -f "${OUTPUTDIR}/kubeconfig-${edgecluster}" ]]; then
                extract_kubeconfig ${edgecluster}
            else
                export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgecluster}"
            fi

            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'
            trust_internal_registry 'edgecluster' ${edgecluster}
            if [[ ! -f ${OUTPUTDIR}/catalogsource-${edgecluster}.yaml ]]; then
                echo "CatalogSource File does not exists, generating a new one..."
                create_cs 'edgecluster' ${edgecluster}
            fi
            recover_mapping
            recover_edgecluster_rsa ${edgecluster}

            RCICSP=$(oc --kubeconfig=${EDGE_KUBECONFIG} get ImageContentSourcePolicy ztpfw-${edgecluster} | wc -l || true)
            if [[ ${RCICSP} -eq 2 ]]; then
                echo ">>>> Waiting for old stuff deletion..."
            else
                echo ">>>> Creating ICSP for: ${edgecluster}"
                # Use the Edge-cluster's registry as a source
                source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'edgecluster'
                icsp_mutate ${OUTPUTDIR}/${MAP_FILENAME} ${DESTINATION_REGISTRY} ${edgecluster}
                icsp_maker ${EDGE_MAPPING_FILE} ${OUTPUTDIR}/icsp-${edgecluster}.yaml ${edgecluster}

                # Clean Old stuff
                oc --kubeconfig=${EDGE_KUBECONFIG} delete -f ${OUTPUTDIR}/catalogsource-hub.yaml || echo "CatalogSoruce already deleted!"
                oc --kubeconfig=${EDGE_KUBECONFIG} delete -f ${OUTPUTDIR}/icsp-hub.yaml || echo "ICSP already deleted!"

                echo ">>>> Waiting for old stuff deletion..."
                sleep 20

                # Deploy New ICSP + CS
                oc --kubeconfig=${EDGE_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-${edgecluster}.yaml
                oc --kubeconfig=${EDGE_KUBECONFIG} apply -f ${OUTPUTDIR}/icsp-${edgecluster}.yaml

                wait_for_mcp_ready ${EDGE_KUBECONFIG} ${edgecluster} 120
            fi
        fi
        _index=$((_index + 1))
    done
fi


debug_status ending