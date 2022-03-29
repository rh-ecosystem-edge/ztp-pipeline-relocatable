Table of contents:

<!-- TOC depthfrom:1 orderedlist:false -->

- [Purpose](#purpose)
- [Why](#why)
- [Requirements](#requirements)
  - [for kcli](#for-kcli)
  - [on the provisioning node](#on-the-provisioning-node)
- [Usage](#usage)
  - [Deploy the Base OpenShift](#deploy-the-base-openshift)
  - [Deploy OpenShift Pipelines](#deploy-openshift-pipelines)
  - [Pipeline for deploying the `Hub`](#pipeline-for-deploying-the-hub)
  - [Pipeline for deploying the Spoke/Edge Cluster](#pipeline-for-deploying-the-spokeedge-cluster)

<!-- /TOC -->

## Purpose

This repository provides a plan which deploys a set of VM's to test the workflow

- `openshift-baremetal-install` is downloaded or compiled from source (with an additional list of `PR` numbers to apply)
- stop the nodes to deploy through IPMI
- launch the install against a set of baremetal nodes. Virtual masters can also be deployed.

## Why

To deploy baremetal using `bare minimum` on the provisioning node

## Requirements

### for kcli

- kcli installed (for RHEL 8/CentOS 8/Fedora, look [here](https://kcli.readthedocs.io/en/latest/#package-install-method)) `curl -1sLf https://dl.cloudsmith.io/public/karmab/kcli/cfg/setup/bash.deb.sh | sudo -E bash`
- an OpenShift pull secret (stored by default in `openshift_pull.json`)

### on the provisioning node

- `libvirt` daemon (with `fw_cfg` support)
- `kvm` QEMU support for creating virtual machines
- two physical bridges:
  - baremetal with a NIC from the external network
  - provisioning with a NIC from the provisioning network. Ideally, assign it an IP of 172.22.0.1/24

## Usage

We'll divide this in several steps:

- Base OpenShift for the Hub
- OpenShift Pipelines
- Deploy the Hub
- Deploy the Spokes/Edge Cluster

### Deploy the Base OpenShift

```sh
cd hacks/deploy-hub-local
./build-hub.sh /root/openshift_pull.json
```

After a while, Kcli would have created the different machines (installer, and 3 masters) for the OpenShift Setup.

If you ssh into the installer machine, you can grab the kube config secret (or copy it)

```sh
kcli scp root@test-ci-installer:/root/ocp/auth/kubeconfig  ~/.kube/config
```

Once `watch -d "oc get clusterversion; oc get nodes; oc get co" report no changes, you're ready to continue was the host has been fully setup for the next step.

### Deploy OpenShift Pipelines

Now that we've the base OpenShift environment, we can deploy the OpenShift Pipelines component by:

```sh
cd pipelines
./bootstrap.sh <branch (Optional)>
```

After a while, the required components are in place and ready to rock!

### Pipeline for deploying the `Hub`

Let's use Tekton CLI to deploy the HUB (optionally we can append `-p git-revision=new-oc-mirror` to use a specific branch )

~~~sh
tkn pipeline start -n spoke-deployer -p spokes-config="$(cat /root/amorgant/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub
~~~

The task might fail as MCP restarts the nodes, rerun it again until it's finished

### Pipeline for deploying the Spoke/Edge Cluster

~~~sh
tkn pipeline start -n spoke-deployer -p spokes-config="$(cat /root/amorgant/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml)" -p kubeconfig=${KUBECONFIG} -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-spokes
~~~

