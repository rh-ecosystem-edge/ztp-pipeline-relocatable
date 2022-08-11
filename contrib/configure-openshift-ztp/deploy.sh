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
    git clone https://github.com/Red-Hat-SE-RTO/openshift-ztp.git
    cd openshift-ztp
    ## Install needed pip modules
    pip3 install -r ./requirements.txt
    pip3 install kubernetes openshift

    ## Install needed Ansible Collections
    ansible-galaxy collection install -r ./collections/requirements.yml

    ## Collecting Manifest.zip for AAP
    YOUR_OSC_ACCESS_KEY=$( oc -n edgecluster-deployer get secret openshift-zip-configs  -o jsonpath="{.data.AWS_ACCESS_KEY_ID}" | base64 --decode)
    YOUR_OSC_SECRET_KEY=$( oc -n edgecluster-deployer get secret openshift-zip-configs  -o jsonpath="{.data.AWS_SECRET_ACCESS_KEY}" | base64 --decode)
    curl -OL https://raw.githubusercontent.com/tosin2013/openshift-4-deployment-notes/master/aws/configure-aws-cli.sh
    chmod +x configure-aws-cli.sh 
    export SKIP_CHECK_CALLER_IDENTITY="true"
    ./configure-aws-cli.sh -i ${YOUR_OSC_ACCESS_KEY} ${YOUR_OSC_SECRET_KEY} us-east-1
    aws --endpoint-url  https://s3-openshift-storage.apps.rto.tosins-cloudlabs.com/ s3 ls
    aws  --endpoint-url  https://s3-openshift-storage.apps.rto.tosins-cloudlabs.com/ s3 cp  s3://openshift-zip-configs/manifest_tower-dev_20220811T151908Z.zip .

    ## Configure the Hub cluster Operators and Workloads, namely RHACM, AAP2, and RH GitOps (ArgoCD)
    ansible-playbook ansible/2_configure.yaml \
    -e configure_rhacm=true \
    -e configure_aap2_controller=true \
    -e configure_rh_gitops=true \
    -e pull_secret_path="${PULL_SECRET}" -e 'ansible_python_interpreter=/usr/bin/python3'  
    -e subscription_manifest_path=manifest_tower-dev_20220811T151908Z.zip -vv


    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
