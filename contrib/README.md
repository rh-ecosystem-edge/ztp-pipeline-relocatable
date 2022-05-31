# Contrib

The goal of this document is to explain the procedure to add custom steps to the cluster's deployment pipeline.

- [Contrib](#contrib)
- [1. Introduction to contrib template](#1-introduction-to-contrib-template)
- [2. Create contrib feature](#2-create-contrib-feature)
- [3. Create pipeline tasks](#3-create-pipeline-tasks)
- [4. Add tasks to the edgecluster pipeline](#4-add-tasks-to-the-edgecluster-pipeline)

# 1. Introduction to contrib template

The specs of a contrib feature is as desribed in the template, this is a basic structure to use as example to implement custom features to be added in the edgeclusters clusters.

```
template
├── deploy.sh
├── manifests
│   └── 01-template-namespace.yaml
└── verify.sh
```

- **verify.sh**

  In order to keep the idempotency of the contrib feature, the verify.sh script is used to check if the feature is already installed. Hence within this script should be all the checks to verify if the feature is already installed, this way it is posible to rerun the whole pipeline.

- **deploy.sh**

  This script is the main script to install the feature, it should be called by the task from the Tekton pipeline, and should contain all the step required to deploy the requried feature in the edgecluster cluster. Before start any step it should be sure that the feature is not already installed, this is done by calling the verify.sh script. If the stderr of the verify.sh script is `0`, the feature is already installed and the deploy.sh script should not be executed.

- **manifests**

  Within the folder `manifests` should the .yaml files to be applied to the edgecluster cluster. In the template example is just a manifest to create a namespace called `contrib-template`. In here can be created as must as needed manifests objects to be applied to the edgecluster cluster, called from the `deploy.sh` script.

# 2. Create contrib feature

The first thing to do is to create a directory for the contrib features under the `contrib` folder, using as base the `contrib/template` example. The directory name should be the same as the feature name. In the example, the name of the directory can be `contrib/deploy-app`.

```bash
cd contrib
cp -r template deploy-app
```

The contrib feature directory should looks like this after adding some manifests with the desired resources to be deployed on the edgecluster clusters:

```
deploy-app
├── deploy.sh
├── manifests
│   └── 01-deploy-app-resource1.yaml
│   └── 02-deploy-app-resource2.yaml
│   └── ...
└── verify.sh
```

At this point all the scripts and manifests should be updated with the required instructions to deploy the feature in the edgecluster cluster.

# 3. Create pipeline tasks

Once the contrib feature is created, the next step is to create the Tekton tasks to call the deploy script. The tasks should be created in the `pipelines/resources/contrib/` folder.
The current template example can be copied to the folder and renamed to `deploy-app`.

```bash
cp pipelines/resources/contrib/contrib-template.yaml pipelines/resources/contrib/deploy-app.yaml
```

After copy the task definition from the template, can be updated with the required instructions to call the previously created deploy.sh script and define the variables and/or config if required.

Be aware to add to the `kustomization.yaml` the name of the task reference name.

# 4. Add tasks to the edgecluster pipeline

The last step is to add the task to the pipeline. The task should be added to the edgecluster pipelines file at `pipelines/resources/deploy-ztp-edgeclusters.yaml`. The position of the call to the new task depend of the nature of the feature and the dependencies of the features from other steps in the pipeline.

The snippet below should be added in the `deploy-ztp-edgeclusters.yaml` updating the values that fit for the desired task run. It is important to be carefull with the value of `spec.tasks[].name.runAfter`, in here has to be defined the previous task of our run in the pipeline.

```yaml
- name: contrib-template
    taskRef:
      name: edgecluster-contrib-template
    params:
      - name: edgeclusters-config
        value: $(params.edgeclusters-config)
      - name: kubeconfig
        value: $(params.kubeconfig)
      - name: ztp-container-image
        value: $(params.ztp-container-image)
    runAfter:
      - previous-step # here has to be the name of the previous step where this task should be called
    workspaces:
      - name: ztp
        workspace: ztp
```
