# ZTP Using Openshift Pipelines

## Prereqs

- You need at least a hub cluster deployed and functional and an accesible Kubeconfig file
- The clsuter should be IPv4/Connected
- An Spokes file (you can create one using [this](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/blob/tekton-pipeline/examples/config.yaml) as a sample.

## Quickstart

- First you need to execute the script using curl command

## Clarifications

- This is to achieve the final end of ZTP at the factory project.
- It's not compatible with typical ZTP workflow


## Workflow

### Bootstrap

- Execute the bootstrap script file `pipelines/bootstrap.sh ${KUBECONFIG}` you can do that using this command:

```
export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
curl -sLk https://raw.githubusercontent.com/rh-ecosystem-edge/ztp-pipeline-relocatable/tekton-pipeline/pipelines/bootstrap.sh | bash -s -- ${KUBECONFIG}
```

- This is the output:
```
>>>> Cloning Repository into your local folder"
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Cloning into 'ztp-pipeline-relocatable'...
remote: Enumerating objects: 3787, done.
remote: Counting objects: 100% (1544/1544), done.
remote: Compressing objects: 100% (938/938), done.
remote: Total 3787 (delta 936), reused 1145 (delta 577), pack-reused 2243
Receiving objects: 100% (3787/3787), 694.35 KiB | 7.71 MiB/s, done.
Resolving deltas: 100% (2156/2156), done.

>>>> Deploy Openshift Pipelines
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
subscription.operators.coreos.com/openshift-pipelines-operator-rh unchanged
>>>> Waiting for: Openshift Pipelines
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
>>>> Deploying Kubeframe Pipelines and tasks
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
pipeline.tekton.dev/deploy-ztp-hub configured
pipeline.tekton.dev/deploy-ztp-spokes configured
task.tekton.dev/common-pre-flight configured
task.tekton.dev/hub-deploy-acm configured
task.tekton.dev/hub-deploy-disconnected-registry configured
task.tekton.dev/hub-deploy-httpd-server configured
task.tekton.dev/hub-deploy-hub-config configured
task.tekton.dev/hub-deploy-icsp-hub configured
task.tekton.dev/hub-save-config configured
task.tekton.dev/spoke-deploy-disconnected-registry-spokes configured
task.tekton.dev/spoke-deploy-icsp-spokes-post configured
task.tekton.dev/spoke-deploy-icsp-spokes-pre configured
task.tekton.dev/spoke-deploy-metallb configured
task.tekton.dev/spoke-deploy-ocs configured
task.tekton.dev/spoke-deploy-spoke configured
task.tekton.dev/spoke-deploy-workers configured
task.tekton.dev/spoke-detach-cluster configured
task.tekton.dev/spoke-restore-hub-config configured
```

This script will deploy Openshift-Pipelines and enable the Tasks and Pipelines into your Hub cluster.
Then you can continue the flow using the Command Line or the UI.


### Hub Pipeline

You will pass some arguments to the Task or Pipeline in order to execute them, for that you need to use the Tekton CLI `tkn` using this [link](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/pipeline/latest/tkn-linux-amd64-0.21.0.tar.gz)

Now you need to have in mind the arguments for the Pipeline:

- KUBECONFIG=
- SPOKES_FILE=
- SYNC='yes|no'

### Spoke Pipeline
