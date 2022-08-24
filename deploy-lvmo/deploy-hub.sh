#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

if ! ./verify_hub.sh; then
    echo ">>>> Modify files to replace with pipeline info gathered"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    sed -i "s/CHANGEME/$OC_ODF_VERSION/g" manifests/03-LVMO-Subscription.yaml
    sed -i "s/CATALOG_SOURCE/redhat-operators/g" manifests/03-LVMO-Subscription.yaml

        echo ">>>> Deploy manifests to install LSO and LocalVolume: hub cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

        oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/01-Namespace.yaml
        sleep 2
        oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/02-LVMO-OperatorGroup.yaml
        sleep 2
        oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/03-LVMO-Subscription.yaml
        sleep 5

        echo ">>>> Waiting for subscription and crd on: hub cluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        declare -a LVMOCRDS=("lvmclusters.lvm.topolvm.io" "lvmvolumegroupnodestatuses.lvm.topolvm.io" "lvmvolumegroups.lvm.topolvm.io")
        for crd in ${LVMOCRDS[@]}; do
            check_resource "crd" "${crd}" "Established" "openshift-local-storage" "${KUBECONFIG_HUB}"
        done

        echo ">>>> Render and apply manifest to deploy LVMCluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>"
        oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/04-LVMO-LVMOCluster.yaml
        sleep 60

        echo ">>>> Waiting for: LVMCluster"
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        timeout=0
        ready=false
        while [ "$timeout" -lt "1000" ]; do
            if [[ $(oc get --kubeconfig=${KUBECONFIG_HUB} -n openshift-storage lvmcluster -ojsonpath='{.items[*].status.ready}') == "true" ]]; then
                ready=true
                break
            fi
            sleep 5
            timeout=$((timeout + 1))
        done
        if [ "$ready" == "false" ]; then
            echo "timeout waiting for LVMCluster deployment..."
            exit 1
        fi

    oc --kubeconfig=${KUBECONFIG_HUB} patch storageclass odf-lvm-vg1 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f manifests/05-Hub-PVC.yaml
fi
echo ">>>>EOF"
echo ">>>>>>>"
