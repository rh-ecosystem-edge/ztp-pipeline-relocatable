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
    ${SCP_COMMAND} -i ${RSA_KEY_FILE} -r "${src_files[@]}" core@${dst_node}:${dst_folder}
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
    edgename=${1}
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${edgename}"
    echo "Exporting EDGE_KUBECONFIG: ${EDGE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n ${edgename} ${edgename}-admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d >${EDGE_KUBECONFIG}
}

function generate_mapping() {
    echo ">>>> Loading Common file"
    ## Not fully sure but we create the base mapping file using the hub definition and then, when it makes sense we mutate it changing the destination registry
    source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'hub'

    MAP_FILENAME=$1
    SOURCE_INDEX=$2
    INDEX_MANIFESTS=${OUTPUTDIR}/mappings/

    mkdir -p $INDEX_MANIFESTS


    echo ">>>> Copying mapping file to ${OUTPUTDIR}/mapping.txt"
    unalias cp &>/dev/null || echo "Unaliased cp: Done!"
    cp -f ${INDEX_MANIFESTS}/mapping.txt ${MAP_FILENAME}
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

if [[ ${1} == 'edgecluster' ]]; then
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

	    HUB_DEFAULT_SOURCES_DISABLED=$(oc --kubeconfig=$KUBECONFIG_HUB get OperatorHub cluster --template="{{.spec.disableAllDefaultSources}}")
	    EDGE_DEFAULT_SOURCES_DISABLED=$(oc --kubeconfig=$EDGE_KUBECONFIG get OperatorHub cluster --template="{{.spec.disableAllDefaultSources}}")
	    if [[ "${HUB_DEFAULT_SOURCES_DISABLED}" != "true" || "${EDGE_DEFAULT_SOURCES_DISABLED}" == "true" ]];
	    then
		 echo "Local cluster already disconnected! No need to apply hub catalogs again"
	         exit 0
	    fi

	    echo "Creating CatalogSource and ICSPs from Hub"
	    export APPLY_MANIFEST_DIR=${OUTPUTDIR}/manifests-apply
	    mkdir -p $APPLY_MANIFEST_DIR 
	    cat <<EOF >$APPLY_MANIFEST_DIR/operator-hub.patch
[
  {
    "op": "add",
    "path": "/spec/disableAllDefaultSources",
    "value": true
  }
]
EOF

	    for catalog in $(oc --kubeconfig=$KUBECONFIG_HUB get catalogsource -n openshift-marketplace -ojson | jq -r ".items[] | .metadata.name");
	    do
		MANIFESTS_DIR="${OUTPUTDIR}/$catalog-manifests/"
		mkdir -p $MANIFESTS_DIR
		INDEX=$(oc --kubeconfig=$KUBECONFIG_HUB get catalogsource $catalog -n openshift-marketplace --template={{.spec.image}});
		echo ">>>> Creating manifests for ${catalog}"
		echo "DEBUG: GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror #${INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=${MANIFESTS_DIR}"
		GODEBUG=x509ignoreCN=0 oc --kubeconfig=${KUBECONFIG_HUB} adm catalog mirror ${INDEX} ${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS} --registry-config=${PULL_SECRET} --manifests-only --to-manifests=$MANIFESTS_DIR
		cp $MANIFESTS_DIR/imageContentSourcePolicy.yaml $APPLY_MANIFEST_DIR/$catalog-icsp.yaml
		oc --kubeconfig=${KUBECONFIG_HUB} get catalogsource -n openshift-marketplace $catalog -ojson | jq 'del(.metadata.resourceVersion,.metadata.uid,.metadata.selfLink,.metadata.creationTimestamp,.metadata.annotations,.metadata.generation,.metadata.ownerReferences,.status)' | yq eval . --prettyPrint > $APPLY_MANIFEST_DIR/catalogsource-hub-$catalog.yaml
	    done

            recover_edgecluster_rsa ${edgecluster}



            # In this stage the edgecluster's registry does not exist, so we need to trust the Hub's ingress cert
            # Check API
            echo ">> Checking edgecluster API: ${STAGE}"
            echo ">> Kubeconfig: ${EDGE_KUBECONFIG}"
            RCAPI=$(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes)
            # If not API
            if [[ -z ${RCAPI} ]]; then
                # Grab EDGE IP
		EDGE_NODE_IP=$(grab_node_ext_ips ${edgecluster} ${_index})
                check_connectivity "${EDGE_NODE_IP}"
                # Execute commands and Copy files
                ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} "mkdir -p ~/manifests/ ~/.kube"
                copy_files "${EDGE_KUBECONFIG}" "${EDGE_NODE_IP}" "./.kube/config"
                copy_files "${APPLY_MANIFEST_DIR}" "${EDGE_NODE_IP}" "./manifests/icsp"
                # Check ICSP
                OC_COMMAND="${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${EDGE_NODE_IP} oc"
                MANIFESTS_PATH='manifests/icsp'
            else
                OC_COMMAND="oc --kubeconfig=${EDGE_KUBECONFIG}"
                MANIFESTS_PATH="${APPLY_MANIFEST_DIR}"
            fi

	    # Edge-cluster Sync from the Hub cluster as a Source
	    echo ">>>> Deploying ICSP for: ${edgecluster} using the Hub as a source"
	    ${OC_COMMAND} patch OperatorHub cluster --type=json --patch-file=$MANIFESTS_PATH/operator-hub.patch
	    ${OC_COMMAND} apply -f ${MANIFESTS_PATH}
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
            recover_edgecluster_rsa ${edgecluster}

	    export APPLY_MANIFEST_DIR=${OUTPUTDIR}/icsp
	    mkdir -p $APPLY_MANIFEST_DIR 

            RCICSP=$(oc --kubeconfig=${EDGE_KUBECONFIG} get ImageContentSourcePolicy ztpfw-${edgecluster} | wc -l || true)
            if [[ ${RCICSP} -eq 2 ]]; then
                echo ">>>> Waiting for old stuff deletion..."
            else
                echo ">>>> Creating ICSP for: ${edgecluster}"
                # Use the Edge-cluster's registry as a source
                source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh 'edgecluster'

                # Clean Old stuff
                oc --kubeconfig=${EDGE_KUBECONFIG} delete -f ${OUTPUTDIR}/icsp-hub.yaml || echo "ICSP already deleted!"

                echo ">>>> Waiting for old stuff deletion..."
                sleep 20

                # Deploy New ICSP + CS
                oc --kubeconfig=${EDGE_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-${edgecluster}.yaml
                oc --kubeconfig=${EDGE_KUBECONFIG} apply -f ${APPLY_MANIFEST_DIR}

                wait_for_mcp_ready ${EDGE_KUBECONFIG} ${edgecluster} 120
            fi
        fi
        _index=$((_index + 1))
    done
fi
