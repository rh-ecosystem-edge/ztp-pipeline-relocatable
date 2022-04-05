#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $spoke secret/$spoke-admin-kubeconfig --to - >${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if ./verify.sh; then

    if [[ -z ${ALLSPOKES} ]]; then
        ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
    fi

    for spoke in ${ALLSPOKES}; do
        echo ">>>> Deploy manifests to install GPU and NFD operators: ${spoke}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Extract Kubeconfig for ${spoke}"
        extract_kubeconfig ${spoke}

        echo "Installing NFD operator for ${spoke}"
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-nfd-namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-nfd-operator-group.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-nfd-subscription.yaml
        sleep 2

        echo ">>>> Waiting for subscription and crd on: ${spoke}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            echo KUBESPOKE=${SPOKE_KUBECONFIG}
            if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get crd | grep localvolumes.local.storage.openshift.io | wc -l) -eq 1 ]]; then
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

        echo ">>>> Render and apply manifests for LocalVolume on: ${spoke}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        render_file manifests/04-LSO-LocalVolume.yaml
        sleep 20

        echo ">>>> Waiting for: LSO PVs on ${spoke}"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc --kubeconfig=${SPOKE_KUBECONFIG} get pv -o name | wc -l) -ge 3 ]]; then
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
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/01-OCS-Namespace.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/02-OCS-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${SPOKE_KUBECONFIG} apply -f manifests/03-OCS-Subscription.yaml
        sleep 60

        echo ">>>> Labeling nodes for OCS"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        counter=0
        for node in $(oc --kubeconfig=${SPOKE_KUBECONFIG} get node -o name); do
            oc --kubeconfig=${SPOKE_KUBECONFIG} label $node cluster.ocs.openshift.io/openshift-storage='' --overwrite=true
            oc --kubeconfig=${SPOKE_KUBECONFIG} label $node topology.rook.io/rack=rack${counter} --overwrite=true
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
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} -n openshift-storage storagecluster -ojsonpath='{.items[*].status.phase}') == "Ready" ]]; then
                ready=true
                break
            fi
            sleep 5
            timeout=$((timeout + 1))
        done
        if [ "$ready" == "false" ]; then
            echo "timeout waiting for OCS deployment..."
            exit 1
        fi
    done
    oc --kubeconfig=${SPOKE_KUBECONFIG} patch storageclass ocs-storagecluster-cephfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
else
    echo ">>>> This step is not neccesary, everything looks ready"
fi

echo ">>>>EOF"
echo ">>>>>>>"
