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
    yum install ansible git python3-pip -y

    ##############################################################################
    # Assuming you have an OCP 4.9+ cluster deployed with OpenShift Assisted Installer Service (OAS), you can simply run the following to bootstrap it into a Hub Cluster:
    # https://github.com/Red-Hat-SE-RTO/openshift-ztp
    ##############################################################################
    git clone https://github.com/Red-Hat-SE-RTO/openshift-ztp.git
    cd openshift-ztp
    ## Install needed pip modules
    pip3 install -r ./requirements.txt

    ## Install needed Ansible Collections
    ansible-galaxy collection install -r ./collections/requirements.yml

    ## Configure the Hub cluster Operators and Workloads, namely RHACM, AAP2, and RH GitOps (ArgoCD)
    ansible-playbook ansible/2_configure.yaml \
    -e configure_rhacm=true \
    -e configure_aap2_controller=true \
    -e configure_rh_gitops=true \
    -e pull_secret_path="${PULL_SECRET}" 


    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
