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
export SPOKEFILE=/home/${USER}/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml
```

**Populate SPOKEFILE with the items below**
> You may change them to your needs
```
cat >${SPOKEFILE}<<EOF
config:
  clusterimageset: openshift-v4.9.0
  OC_OCP_VERSION: "4.9.0" # Change to match your cluster version
  OC_OCP_TAG: "4.9.0-x86_64"
  OC_RHCOS_RELEASE: "49.83.202103251640-0"
  OC_ACM_VERSION: "2.4"
  OC_OCS_VERSION: "4.8"
  CLOUD_DEPLOYMENT: "true"
EOF
```
## Change pipeline image
> change your pipeline to point to `quay.io/takinosh/ztpfw-pipeline`
```
spec:
  description: Tekton Pipeline to deploy ZTPFW Hub Cluster
  params:
    - default: 'quay.io/takinosh/ztpfw-pipeline:dev'
```

## Start the deploy-ztp-hub against the ACM hub cluster
```
TEST=$(find  $HOME  -type f -name "kubeconfig")
tkn pipeline start -n spoke-deployer -p ztp-container-image="quay.io/takinosh/ztpfw-pipeline:dev" -p spokes-config="$(cat ${SPOKEFILE})" -p kubeconfig="${TEST}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub-cloud
```

## TESTING
```
oc adm policy add-cluster-role-to-user cluster-admin spokes-deployer
# HACK
oc policy add-role-to-user admin -z pipeline -n spoke-deployer
oc policy add-role-to-user admin system:serviceaccount:spoke-deployer:pipeline
```

