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
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge --patch '{"spec":{"defaultRoute":true}}' 

echo ">>>> Get the pull secret from hub to file ./pull-secret.json"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d > ./pull-secret.json

echo ">>>> Get the registry cert and update pull secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
OPENSHIFT_RELEASE_IMAGE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.image'})
OCP_RELEASE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.version'})-x86_64
LOCAL_REG=$(oc get route -n openshift-image-registry | awk '{print $2}' | tail -1)
oc get secret -n openshift-ingress  router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d > /etc/pki/ca-trust/source/anchors/internal-registry.crt
update-ca-trust extract

oc login -u kubeadmin -p "$OC_KUBEADMIN_PASS_SECRET"
TOKEN=$(oc whoami -t)
oc logout ; oc config use-context admin
KEY=$( echo -n kubeadmin:"$TOKEN" | base64 -w0)
export REGISTRY_NAME="$(oc get route -n openshift-image-registry default-route -o jsonpath={'.status.ingress[0].host'})"
jq ".auths += {\"$REGISTRY_NAME\": {\"auth\": \"$KEY\",\"email\": \"info@alklabs.com\"}}" < ./pull-secret.json  > ./pull-secret-internal-registry.json

oc adm release mirror -a ./pull-secret-internal-registry.json --from="$OPENSHIFT_RELEASE_IMAGE" --to-release-image="${LOCAL_REG}"/ocp4/openshift4:"${OCP_RELEASE}" --to="${LOCAL_REG}"/ocp4/openshift4

echo ">>>>EOF"
echo ">>>>>>>"


