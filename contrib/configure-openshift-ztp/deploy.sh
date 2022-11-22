#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m



if ./verify.sh; then
    # Load common vars
    source ${WORKDIR}/shared-utils/common.sh
    echo ">>>> Deploy manifests to create template namespace on HUB Cluster"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################
    ### TEMPORARY INSTALLING the packages for ansible: 
    yum install epel-next-release -y
    yum install ansible git python3-pip unzip -y

    ##############################################################################
    # Assuming you have an OCP 4.9+ cluster deployed with OpenShift Assisted Installer Service (OAS), you can simply run the following to bootstrap it into a Hub Cluster:
    # https://github.com/Red-Hat-SE-RTO/openshift-ztp
    ##############################################################################
    git clone ${OPENSHIFT_ZTP_VSPHERE_REPO}
    cd openshift-ztp
    ## Install needed pip modules
    pip3 install -r ./requirements.txt
    pip3 install kubernetes openshift

    ## Install needed Ansible Collections
    ansible-galaxy collection install -r ./collections/requirements.yml

    ## Collecting Manifest.zip for AA    
    ## Configure the Hub cluster Operators and Workloads, namely RHACM, AAP2, and RH GitOps (ArgoCD)
    ls -lath /opt/ztp
    sleep 5s

    TOWER_MAINFEST_ZIP=$(ls /opt/ztp| grep manifest_tower)
    if [ -z "${TOWER_MAINFEST_ZIP}" ]; then
        echo "ERROR: Tower manifest zip file not found in $/opt/ztp"
        exit 1
    fi
    ansible-playbook ansible/2_configure.yaml \
    -e configure_rhacm=true \
    -e configure_aap2_controller=true \
    -e configure_rh_gitops=true \
    -e use_services_not_routes=false \
    -e pull_secret_path="${PULL_SECRET}" -e 'ansible_python_interpreter=/usr/bin/python3'  \
    -e subscription_manifest_path="/opt/ztp/${TOWER_MAINFEST_ZIP}" -vv


    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
