# VMWARE integration

## Development Requirements 
* OpenShift 4.10 cluster running on VMWARE
* ODF installed (3 masters, 3 workers for ODF)
* OpenShift Pipelines Installed
* RHEL/CENTOS jumpbox

## Dev Box for deployments
[ZTP for Factory Workflow qubinode dev box](https://gist.github.com/tosin2013/3b99a883078025de1a5327d532bf2cae)

**Execute the bootstrap script file pipelines/bootstrap.sh ${KUBECONFIG} you can do that using this command:**
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find   $HOME/.kcli/clusters/${CLUSTER_NAME}  -type f -name "kubeconfig")
curl -sLk https://raw.githubusercontent.com/rh-ecosystem-edge/ztp-pipeline-relocatable/main/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```

## Development
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find   $HOME/.kcli/clusters/${CLUSTER_NAME}  -type f -name "kubeconfig")
$ cd /root/ztp-pipeline-relocatable/pipelines
$ ./bootstrap.sh
```

**Export SPOKEFILE env variable**
```
$ export SPOKES_PATH=/root/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml
```

## Configure HTTPD and Sync the Disconnected Registry Pipeline 
> this command may need to be ran more than once since it updates certificates in the mch
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find   $HOME/.kcli/clusters/${CLUSTER_NAME}  -type f -name "kubeconfig")
$ tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKES_PATH})" -p kubeconfig="${KUBECONFIG}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-disconnected-registry
```

## Install ODF 4.10 on hub cluster 

## Start the deploy-ztp-hub against the ACM hub cluster
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find $HOME/.kcli/clusters/${CLUSTER_NAME} -type f -name "kubeconfig")
$ tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKES_PATH})" -p kubeconfig="${KUBECONFIG}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-cloud
```

## Configure OpenShift cluster with secure ssl keys

## Clone openshift-ztp.git repo
> Username: user-1
> Password: openshift
```
cd ~
git clone https://gitea-gitea.apps.ocp4.rtoztplab.com/user-1/openshift-ztp.git
cd ~/openshift-ztp
```

## Setup the Hub Cluster
```
## Install needed pip modules
pip3 install -r ./requirements.txt

## Install needed Ansible Collections
ansible-galaxy collection install -r ./collections/requirements.yml
ansible-galaxy collection install kubernetes openshift


cp ~/openshift_pull.json  ~/rh-ocp-pull-secret.json

## Log into the Hub cluster with a cluster-admin user:
CLUSTER_NAME="ocp4"
export KUBECONFIG=$(find $HOME/.kcli/clusters/${CLUSTER_NAME} -type f -name "kubeconfig")

## Configure the Hub cluster Operators and Workloads, namely RHACM, AAP2, and RH GitOps (ArgoCD)
ansible-playbook ansible/2_configure.yaml --extra-vars subscription_manifest_path=/tmp/aap2-subscription-manifest.zip

## Create credentials for vSphere Infrastructure, Pull Secret, Git credentials, etc
ansible-playbook \
 -e vcenter_username="administrator@vsphere.local" \
 -e vcenter_password='somePass!' \
 -e vcenter_fqdn="vcenter.example.com" \
 ansible/3_create_credentials.yaml
```

## Spoke Cluster Manifest Generation

Once the Hub has been set up and configured, with Credentials available, you can create a set of Spoke Cluster manifests.  The **Spoke Cluster Manifest Generation** Ansible Playbook can be run locally or via Ansible Tower/AAP 2 Controller.  The previously run `2_configure.yaml` Playbook will set up a Job Template.

There are a set of example variables that would be passed to the **Spoke Cluster Manifest Generation** Playbook in `example_vars` - use it as such:

```bash
# Single Node OpenShift
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-singleNode.yaml" create_spoke_manifests.yml

# 3 Node Converged Control Plane + Application Node Cluster
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-3nodeConverged.yaml" create_spoke_manifests.yml

# 3 Control Plane + 3+ Application Node Cluster
ansible-playbook -i inv_localhost -e "@example_vars/create_spoke_manifests-haCluster.yaml" create_spoke_manifests.yml
```