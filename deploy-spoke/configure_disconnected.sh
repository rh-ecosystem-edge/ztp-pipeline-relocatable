#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

function extract_kubeconfig() {
    ## Put Hub Kubeconfig in a safe place
    echo ">>>> Extracting all Kubeconfig from Hub cluster"
    if [[ ! -f "${OUTPUTDIR}/kubeconfig-hub" ]];then 
        cp ${KUBECONFIG_HUB} "${OUTPUTDIR}/kubeconfig-hub"
    fi

    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${1}"
    echo "Exporting SPOKE_KUBECONFIG: ${SPOKE_KUBECONFIG}"
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath=‘{.data.kubeconfig}’ | base64 -d > ${SPOKE_KUBECONFIG}
}

function icsp_mutate() {
    echo ">>>> Mutating Registry for: ${spoke}"
    MAP=${1}
    DST_REG=${2}
    SPOKE=${3}
    HUB_REG_ROUTE="$(oc --kubeconfig=${KUBECONFIG_HUB} get route -n ${REGISTRY} ${REGISTRY} -o jsonpath={'.status.ingress[0].host'})"
    sed "s/${HUB_REG_ROUTE}/${DST_REG}/g" ${MAP} | tee "${MAP%%.*}-${spoke}.txt"
}

function recover_mapping() {
    echo ">>>> Finding Map file for OLM Sync"
    MAP_FILE=$(find ${WORKDIR} -name ${MAP_FILENAME})
    cp ${MAP_FILE} ${OUTPUTDIR}/${MAP_FILENAME}
}

function gen_header() {
    cat <<EOF >${ICSP_OUTFILE}
---
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  labels:
    operators.openshift.org/catalog: "true"
  name: kubeframe-${cluster}
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
        echo "  icsp_maker <MAPPING FILE> <ICSP DESTINATION FILE> hub|<spoke>"
        exit 1
    fi

    export MAP_FILE=${1}
    export ICSP_OUTFILE=${2}
    export cluster=${3}

    gen_header ${ICSP_OUTFILE} ${cluster}

    while read entry
    do
        RAW_SRC=${entry%%=*}
        RAW_DST=${entry##*=}
        SRC_IMG="${RAW_SRC%%@*}"
        DST_IMG="${RAW_DST%%:*}"
        add_icsp_entry ${SRC_IMG} ${DST_IMG}
    done < ${MAP_FILE}
}

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh
export MAP_FILENAME='mapping.txt'

recover_mapping 

MODE=${1}

if [[ ${MODE} == 'hub' ]];then
    # Validation
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 hub|spoke <STAGE (mandatory on spoke MODE)>"
        exit 1
    fi

    echo ">>>> Creating ICSP for: Hub"
    TARGET_KUBECONFIG=${KUBECONFIG_HUB}
    icsp_maker ${OUTPUTDIR}/${MAP_FILENAME} ${OUTPUTDIR}/icsp-hub.yaml 'hub'
    oc --kubeconfig=${TARGET_KUBECONFIG} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
    oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-hub.yaml
    oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/icsp-hub.yaml

elif [[ ${MODE} == 'spoke' ]];then
    # Validation
    if [[ $# -lt 2 ]]; then
        echo "Usage :"
        echo "  $0 hub|spoke <STAGE (mandatory on spoke MODE)>"
        exit 1
    fi

    # STAGE is the value to reflect which step are you in
    #    if you didn't synced from Hub to Spoke you need to put 'pre'
    #    if you already synced from Hub to Spoke you need to put 'post'
    STAGE=${2}

    if [[ -z "${ALLSPOKES}" ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi
    
    for spoke in ${ALLSPOKES}
    do
        # Get Spoke Kubeconfig
        if [[ ! -f "${OUTPUTDIR}/kubeconfig-${spoke}" ]]; then
            extract_kubeconfig ${spoke}
        else
            export SPOKE_KUBECONFIG="${OUTPUTDIR}/kubeconfig-${spoke}"
        fi

        TARGET_KUBECONFIG=${SPOKE_KUBECONFIG}

        # Logic
        if [[ ${STAGE} == 'pre' ]]; then
            # Spoke Sync from the Hub cluster as a Source
            echo ">>>> Deploying ICSP for: ${spoke} using the Hub as a source"
            oc --kubeconfig=${TARGET_KUBECONFIG} patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'
            oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-hub.yaml
            oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/icsp-hub.yaml

        elif [[ ${STAGE} == 'post' ]]; then 
            echo ">>>> Creating ICSP for: ${spoke}"
            # Use the Spoke's registry as a source
            source ${WORKDIR}/${DEPLOY_REGISTRY_DIR}/common.sh
            icsp_mutate ${OUTPUTDIR}/${MAP_FILENAME} ${DESTINATION_REGISTRY} ${spoke}
            icsp_maker ${OUTPUTDIR}/${MAP_FILENAME} ${OUTPUTDIR}/icsp-${spoke}.yaml ${spoke}

            # Clean Old stuff
            oc --kubeconfig=${TARGET_KUBECONFIG} delete -f ${OUTPUTDIR}/catalogsource-hub.yaml
            oc --kubeconfig=${TARGET_KUBECONFIG} delete -f ${OUTPUTDIR}/icsp-hub.yaml

            echo ">>>> Waiting for old stuff deletion..."
            sleep 20

            # Deploy New ICSP + CS
            oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/catalogsource-${spoke}.yaml
            oc --kubeconfig=${TARGET_KUBECONFIG} apply -f ${OUTPUTDIR}/icsp-${spoke}.yaml
        fi
    done
fi
