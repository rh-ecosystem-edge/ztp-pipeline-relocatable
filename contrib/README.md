# Contrib

The goal of this document is to explain the procedure to add custom features to the spoke clusters.

- [Contrib](#contrib)
- [1. Introduction to contrib template](#1-introduction-to-contrib-template)
- [2. Create contrib feature](#2-create-contrib-feature)
- [3. Create pipeline tasks](#3-create-pipeline-tasks)
- [4. Add tasks to the spoke pipeline](#4-add-tasks-to-the-spoke-pipeline)


# 1. Introduction to contrib template

The specs of a contrib feature is as desribed in the template, this is a basic structure to use as example to implement custom features to be added in the spokes clusters.

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

    This script is the main script to install the feature, it should be called by the task from the Tekton pipeline, and should contain all the step required to deploy the requried feature in the spoke cluster. Before start any step it should be sure that the feature is not already installed, this is done by calling the verify.sh script. If the stderr of the verify.sh script is `0`, the feature is already installed and the deploy.sh script should not be executed.

- **manifests**

    Within the folder `manifests` should the .yaml files to be applied to the spoke cluster. In the template example is just the namespace where the feature will be installed.

# 2. Create contrib feature 

The first thing to do is to create a directory for the contrib features under the `contrib` folder, using as base the `contrib/template` example. The directory name should be the same as the feature name. In the example, the name of the directory can be `contrib/deploy-app`.

```bash
cd contrib
cp -r template deploy-app
```

# 3. Create pipeline tasks


# 4. Add tasks to the spoke pipeline
