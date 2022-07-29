#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

function render_file() {
    SOURCE_FILE=${1}
    if [[ ${#} -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ ${DESTINATION_FILE} == "" ]]; then
        envsubst <${SOURCE_FILE} | oc --kubeconfig=${EDGE_KUBECONFIG} apply -f -
    else
        envsubst <${SOURCE_FILE} >${DESTINATION_FILE}
    fi
}

function extract_vars() {
    # Extract variables from config file
    DISKS_PATH=${1}
    raw_disks=$(yq eval "${DISKS_PATH}" "${EDGECLUSTERS_FILE}" | sed s/null//)
    disks=$(echo ${raw_disks} | tr -d '\ ' | sed 's/-/,/g' | sed 's/,*//' | sed 's/,*//')
    disks_count=$(echo ${disks} | sed 's/,/\n/g' | wc -l)

    for node in $(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes -o name | cut -f2 -d/); do
        nodes+="${node},"
    done

    nodes=$(echo ${nodes%*,})

    # Final Variables
    export CHANGEME_NODES="[${nodes}]"
    export CHANGEME_DEVICES="[${disks}]"
    export CHANGEME_STORAGE_DEVICE_SET_COUNT="${disks_count}"
}

function extract_kubeconfig() {
    ## Extract the Edge-cluster kubeconfig and put it on the shared folder
    export EDGE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $edgecluster secret/$edgecluster-admin-kubeconfig --to - >${EDGE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ! ./verify.sh; then
    echo ">>>> Modify files to replace with pipeline info gathered"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    sed -i "s/CHANGEME/$OC_ODF_VERSION/g" manifests/03-ODF-Subscription.yaml

    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi

    for edgecluster in ${ALLEDGECLUSTERS}; do
  	echo "Extract Kubeconfig for ${edgecluster}"
	extract_kubeconfig ${edgecluster}

	export NUM_M=$(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes --no-headers | grep master | wc -l)

	echo "Filling vars for ${edgecluster}"
	extract_vars ".edgeclusters[].${edgecluster}.master0.storage_disk"

        echo ">>>> Deploy manifests to install ODF $OC_ODF_VERSION"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-ODF-Namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-ODF-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-ODF-Subscription.yaml

        sleep 60

        echo ">>>> Labeling nodes for ODF"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        counter=0
        for node in $(oc --kubeconfig=${EDGE_KUBECONFIG} get node -o name -l node-role.kubernetes.io/master); do
            oc --kubeconfig=${EDGE_KUBECONFIG} label $node cluster.ocs.openshift.io/openshift-storage='' --overwrite=true
            oc --kubeconfig=${EDGE_KUBECONFIG} label $node topology.rook.io/rack=rack${counter} --overwrite=true
            let "counter+=1"
        done
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"

	if [ "${NUM_M}" -eq "3" ];
	then
		echo ">>>> Render and apply manifest to deploy ODF StorageCluster"
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
		render_file manifests/04-ODF-StorageCluster.yaml
	else
		echo ">>>> Render and apply manifest to deploy ODF StorageSystem"
		echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
		render_file manifests/04-MCG-StorageCluster.yaml
	fi

        sleep 60
        echo ">>>> Waiting for: ODF Cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc get --kubeconfig=${EDGE_KUBECONFIG} -n openshift-storage storagecluster -ojsonpath='{.items[*].status.phase}') == "Ready" ]]; then
            ready=true
            break
            fi
            sleep 5
            timeout=$((timeout + 1))
        done

	if [ "${NUM_M}" -eq "3" ];
	then
        sleep 30
        oc --kubeconfig=${EDGE_KUBECONFIG} patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    fi

        if [ "$ready" == "false" ]; then
            echo "timeout waiting for ODF deployment..."
            exit 1
        fi
    done
fi
echo ">>>>EOF"
echo ">>>>>>>"
