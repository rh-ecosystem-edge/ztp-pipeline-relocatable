#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig   

echo ">>>> Enable internal registry"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":null}}}}'

echo ">>>> Get the pull secret from hub to file ./pull-secret.json"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d > ./pull-secret.json


oc adm release mirror -a ./pull-secret --from=$OPENSHIFT_RELEASE_IMAGE --to-release-image=${LOCAL_REG}/ocp4:${OCP_RELEASE} --to=${LOCAL_REG}/ocp4

echo ">>>>EOF"
echo ">>>>>>>"


cert del registry: oc get secret -n openshift-ingress  router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d | sudo tee /etc/pki/ca-trust/source/anchors/${HOST}.crt 
 
