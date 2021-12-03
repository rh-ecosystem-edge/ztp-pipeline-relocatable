#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

function render_file() {
    SOURCE_FILE=${1}
    if [[ $# -lt 1 ]]; then
        echo "Usage :"
        echo "  $0 <SOURCE FILE> <(optional) DESTINATION_FILE>"
        exit 1
    fi

    DESTINATION_FILE=${2:-""}
    if [[ "${DESTINATION_FILE}" == "" ]];then
        envsubst < ${SOURCE_FILE} | oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f -  
    else
        envsubst < ${SOURCE_FILE} > ${DESTINATION_FILE}
    fi
}

function extract_vars() {
    # Extract variables from config file
    DISKS_PATH=${1}
    raw_disks=$(yq eval "${DISKS_PATH}" "${SPOKES_FILE}" | sed s/null//)                   
    disks=$(echo ${raw_disks}| tr -d '\ '| sed s#-#,/dev/#g | sed 's/,*//'  | sed 's/,*//')
    
    for node in $(oc --kubeconfig=${SPOKE_KUBECONFIG} get nodes -o name | sed s#node\/##)
    do 
        nodes+="${node},"
    done
    
    nodes=$(echo ${nodes%*,})
    
    # Final Variables
    export CHANGEME_NODES="[${nodes}]"  
    export CHANGEME_DEVICES="[${disks}]"
}

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} get secret -n $spoke $spoke-admin-kubeconfig -o jsonpath=‘{.data.kubeconfig}’ | base64 -di > ${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

echo ">>>> Modify files to replace with pipeline info gathered"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    sed -i "s/CHANGEME/$OC_OCS_VERSION/g" manifests/03-OCS-Subscription.yaml
    
if [[ -z "${ALLSPOKES}" ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi
 
for spoke in ${ALLSPOKES}
do
    echo ">>>> Deploy manifests to install LSO and LocalVolume: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "Extract Kubeconfig for ${spoke}"
        extract_kubeconfig ${spoke}
    echo "Filling vars for ${spoke}"
        extract_vars ".spokes[].${spoke}.master0.storage_disk" 
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-LSO-Namespace.yaml; sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-LSO-OperatorGroup.yaml; sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-LSO-Subscription.yaml; sleep 2
 
    echo ">>>> Waiting for subscription and crd on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "60" ] ; do
            echo KUBESPOKE=${SPOKE_KUBECONFIG}
            if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep localvolumes.local.storage.openshift.io | wc -l) -eq 1 ]];then
                ready=true
                break;
            fi
            echo "Waiting for CRD localvolumes.local.storage.openshift.io to be created"
            sleep 5
            timeout=$(($timeout + 5))
        done
        if [ "$ready" == "false" ] ; then
            echo timeout waiting for CRD localvolumes.local.storage.openshift.io
            exit 1
        fi


    echo ">>>> Render and apply manifests for LocalVolume on: ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-LSO-LocalVolume.yaml
        sleep 20

    echo ">>>> Waiting for: LSO PVs on ${spoke}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "60" ]; do
        	if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get pv -o name | wc -l) -gt 3 ]]; then
        		ready=true
        		break
        	fi
        	sleep 5
        	timeout=$((timeout + 5))
        done

        if [ "$ready" == "false" ]; then
        	echo "timeout waiting for LSO PVs..."
        	exit 1
        fi

    echo ">>>> Deploy manifests to install OCS $OC_OCS_VERSION"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-OCS-Namespace.yaml; sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-OCS-OperatorGroup.yaml; sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-OCS-Subscription.yaml; sleep 60
    
    echo ">>>> Labeling nodes for OCS"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        counter=0
        for node in $(oc --kubeconfig=${SPOKE_KUBECONFIG} get node -o name);
        do
            oc --kubeconfig=${SPOKE_KUBECONFIG} label $node cluster.ocs.openshift.io/openshift-storage=''
            oc --kubeconfig=${SPOKE_KUBECONFIG} label $node topology.rook.io/rack=rack${counter}
            let "counter+=1" 
        done
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
    
    
    echo ">>>> Deploy OCS StorageCluster"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/04-OCS-StorageCluster.yaml
        sleep 60

        echo ">>>> Waiting for: OCS Cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        sleep 240
        while [ "$timeout" -lt "60" ]; do
        	if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} pod -n openshift-storage | grep -i running | wc -l) -eq $(oc --kubeconfig=${SPOKE_KUBECONFIG} get pod -n openshift-storage --no-headers | wc -l) ]]; then
        		ready=true
        		break
        	fi
        	sleep 5
        	timeout=$((timeout + 5))
        done
        if [ "$ready" == "false" ]; then
        	echo "timeout waiting for OCS pods..."
        	exit 1
        fi
done

echo ">>>>EOF"
echo ">>>>>>>"
