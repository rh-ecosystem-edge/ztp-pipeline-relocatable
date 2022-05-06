# VMWARE integration

## Requirements 
* OpenShift 4.10 cluster running on VMWARE
* ODF installed (3 masters, 3 workers for ODF)
* OpenShift Pipelines Installed
* RHEL/CENTOS jumpbox


**Execute the bootstrap script file pipelines/bootstrap.sh ${KUBECONFIG} you can do that using this command:**
```
# export KUBECONFIG=$(find  $HOME/.kcli/clusters/  -type f -name "kubeconfig")
curl -sLk https://raw.githubusercontent.com/rh-ecosystem-edge/ztp-pipeline-relocatable/main/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```

## Development
```
$ curl -sLk https://raw.githubusercontent.com/tosin2013/ztp-pipeline-relocatable/dev/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```

**Export SPOKEFILE env variable**
```
$ export SPOKES_PATH=/root/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml
```

## Configure HTTPD and Sync the Disconnected Registry Pipeline 
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find   $HOME/.kcli/clusters/${CLUSTER_NAME}  -type f -name "kubeconfig")
$ tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKES_PATH})" -p kubeconfig="${KUBECONFIG}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-disconnected-registry
```

## Start the deploy-ztp-hub against the ACM hub cluster
```
$ CLUSTER_NAME="ocp4"
$ KUBECONFIG=$(find $HOME/.kcli/clusters/${CLUSTER_NAME} -type f -name "kubeconfig")
$ tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKES_PATH})" -p kubeconfig="${KUBECONFIG}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-cloud
```

