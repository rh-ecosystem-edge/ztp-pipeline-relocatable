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
    git clone ${OPENSHIFT_ZTP_VSPHERE_REPO}
    cd openshift-ztp
    ## Install needed pip modules
    pip3 install -r ./requirements.txt
    pip3 install kubernetes openshift

    ## Install needed Ansible Collections
    ansible-galaxy collection install -r ./collections/requirements.yml

    ## Create credentials for vSphere Infrastructure, Pull Secret, Git credentials, etc
    ansible-playbook \
    -e vcenter_username="administrator@vsphere.local" \
    -e vcenter_password='somePass!' \
    -e vcenter_fqdn="vcenter.example.com" \
    ansible/3_create_credentials.yaml -e 'ansible_python_interpreter=/usr/bin/python3'  -vv


    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
