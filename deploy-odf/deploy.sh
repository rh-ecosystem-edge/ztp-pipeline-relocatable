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
    disks=$(echo ${raw_disks} | tr -d '\ ' | sed s#-#,#g | sed 's/,*//' | sed 's/,*//')
    disks_count=$(echo ${disks} | sed 's/,/\n/g' | wc -l)

    for node in $(oc --kubeconfig=${EDGE_KUBECONFIG} get nodes -o name | sed s#node\/##); do
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

    index=0
    for edgecluster in ${ALLEDGECLUSTERS}; do
        echo ">>>> Nuking storage disks for: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

        cluster=$(yq eval ".edgeclusters[${index}]|keys" $EDGECLUSTERS_FILE | awk '{print $2}' | xargs echo)

        for master in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${index}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l) - 1)))); do
            EXT_MAC_ADDR=$(yq eval ".edgeclusters[${index}].[].master${master}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})

            recover_edgecluster_rsa ${cluster}

            echo ""
            echo ">>>> Nuking storage disks for Master ${master} Node"
            for agent in $(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${cluster} agent -o name); do
                NODE_IP=$(oc --kubeconfig=${KUBECONFIG_HUB} get -n ${cluster} ${agent} -o jsonpath="{.status.inventory.interfaces[?(@.macAddress==\"${EXT_MAC_ADDR}\")].ipV4Addresses[0]}")
                if [[ -n ${NODE_IP} ]]; then
                    echo "Master Node: ${master}"
                    echo "AGENT: ${agent}"
                    echo "IP: ${NODE_IP%%/*}"
                    echo ">>>>"

                    storage_disks=$(yq e ".edgeclusters[${index}].[].master${master}.storage_disk" $EDGECLUSTERS_FILE | awk '{print $2}' | xargs echo)

                    for disk in ${storage_disks}; do
                        echo ">>> Nuking disk ${disk} at ${master} ${NODE_IP%%/*}"
                        ${SSH_COMMAND} -i ${RSA_KEY_FILE} core@${NODE_IP%%/*} "sudo sgdisk --zap-all $disk;sudo dd if=/dev/zero of=$disk bs=1M count=100 oflag=direct,dsync; sudo blkdiscard $disk"
                    done
                fi
            done
        done

        index=$((index + 1))

        echo ">>>> Deploy manifests to install LSO and LocalVolume: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${edgecluster}"
        extract_kubeconfig ${edgecluster}
        echo "Filling vars for ${edgecluster}"
        extract_vars ".edgeclusters[].${edgecluster}.master0.storage_disk"
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/01-LSO-Namespace.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/02-LSO-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${EDGE_KUBECONFIG} apply -f manifests/03-LSO-Subscription.yaml
        sleep 2

        echo ">>>> Waiting for subscription and crd on: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            echo KUBEEDGE=${EDGE_KUBECONFIG}
            if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get crd | grep localvolumes.local.storage.openshift.io | wc -l) -eq 1 ]]; then
                ready=true
                break
            fi
            echo "Waiting for CRD localvolumes.local.storage.openshift.io to be created"
            sleep 5
            timeout=$((timeout + 5))
        done
        if [ "$ready" == "false" ]; then
            echo timeout waiting for CRD localvolumes.local.storage.openshift.io
            exit 1
        fi

        echo ">>>> Render and apply manifests for LocalVolume on: ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-LSO-LocalVolume.yaml
        sleep 20

        echo ">>>> Waiting for: LSO PVs on ${edgecluster}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc --kubeconfig=${EDGE_KUBECONFIG} get pv -o name | wc -l) -ge 3 ]]; then
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
        for node in $(oc --kubeconfig=${EDGE_KUBECONFIG} get node -o name); do
            oc --kubeconfig=${EDGE_KUBECONFIG} label $node cluster.ocs.openshift.io/openshift-storage='' --overwrite=true
            oc --kubeconfig=${EDGE_KUBECONFIG} label $node topology.rook.io/rack=rack${counter} --overwrite=true
            let "counter+=1"
        done
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"

        echo ">>>> Render and apply manifest to deploy ODF StorageCluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-ODF-StorageCluster.yaml
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
        if [ "$ready" == "false" ]; then
            echo "timeout waiting for ODF deployment..."
            exit 1
        fi
    done
    oc --kubeconfig=${EDGE_KUBECONFIG} patch storageclass ocs-storagecluster-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi
echo ">>>>EOF"
echo ">>>>>>>"
