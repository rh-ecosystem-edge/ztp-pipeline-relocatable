# VMWARE integration

Test Github actions

**Execute the bootstrap script file pipelines/bootstrap.sh ${KUBECONFIG} you can do that using this command:**
```
export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
curl -sLk https://raw.githubusercontent.com/rh-ecosystem-edge/ztp-pipeline-relocatable/main/pipelines/bootstrap.sh ${KUBECONFIG} | bash -s
```
```
export SPOKEFILE=/home/admin/ztp-pipeline-relocatable/hack/deploy-hub-local/spokes.yaml
```
```
cat >${SPOKEFILE}<<EOF
config:
  clusterimageset: openshift-v4.9.0
  OC_OCP_VERSION: "4.9.27"
  OC_OCP_TAG: "4.9.0-x86_64"
  OC_RHCOS_RELEASE: "49.83.202103251640-0"
  OC_ACM_VERSION: "2.4"
  OC_OCS_VERSION: "4.8"
EOF
```

```
oc adm policy add-cluster-role-to-user cluster-admin spokes-deployer
# HACK
oc policy add-role-to-user admin -z pipeline -n spoke-deployer
oc policy add-role-to-user admin system:serviceaccount:spoke-deployer:pipeline
```

```
TEST=$(find  $HOME  -type f -name "kubeconfig")
tkn pipeline start -n spoke-deployer -p spokes-config="$(cat ${SPOKEFILE})" -p kubeconfig="${TEST}" -w name=ztp,claimName=ztp-pvc --timeout 5h --use-param-defaults deploy-ztp-hub
```