# VMWARE integration

## Requirements 
* OpenShift 4.9 cluster running on VMWARE
* ODF installed
* OpenShift Pipelines Installed
* RHEL/CENTOS jumpbox


**Execute the bootstrap script file pipelines/bootstrap.sh ${KUBECONFIG} you can do that using this command:**
```
export KUBECONFIG=$(find  $HOME  -type f -name "kubeconfig")
curl -sLk https://raw.githubusercontent.com/rh-ecosystem-edge/ztp-pipeline-relocatable/main/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```
## Development
```
curl -sLk https://raw.githubusercontent.com/tosin2013/ztp-pipeline-relocatable/dev/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```

**Export SPOKEFILE env variable**
```
export SPOKES_PATH=/root/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml
```

## Start the deploy-ztp-hub against the ACM hub cluster
```
KUBECONFIG=$(find  $HOME  -type f -name "kubeconfig")
tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKES_PATH})" -p kubeconfig="${KUBECONFIG}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-cloud
```

## TESTING
```
oc adm policy add-cluster-role-to-user cluster-admin spokes-deployer
# HACK
oc policy add-role-to-user admin -z pipeline -n spoke-deployer
oc policy add-role-to-user admin system:serviceaccount:spoke-deployer:pipeline
```

