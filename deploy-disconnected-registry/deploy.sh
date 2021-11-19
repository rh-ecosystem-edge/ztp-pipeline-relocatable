#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)echo 

echo ">>>> Enable internal registry"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'; sleep 10
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":null}}}}'; sleep 10
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge --patch '{"spec":{"defaultRoute":true}}'; sleep 60
echo ">>>> Get the pull secret from hub to file ./pull-secret.json"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d > ./pull-secret.json
PULL_SECRET=./pull-secret.json

echo ">>>> Get the registry cert and update pull secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
OPENSHIFT_RELEASE_IMAGE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.image'})
OCP_RELEASE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.version'})-x86_64
LOCAL_REG=$(oc get route -n openshift-image-registry | awk '{print $2}' | tail -1)
oc get secret -n openshift-ingress  router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d > /etc/pki/ca-trust/source/anchors/internal-registry.crt
update-ca-trust extract


if [ $(oc get ns | grep ocp4 | wc -l) -eq 0 ]; then
    oc create ns ocp4
fi

export REGISTRY_NAME="$(oc get route -n openshift-image-registry default-route -o jsonpath={'.status.ingress[0].host'})"
oc -n ocp4 create sa robot
oc -n ocp4 adm policy add-role-to-user registry-editor -z robot
podman login $REGISTRY_NAME -u robot -p $(oc -n ocp4 serviceaccounts get-token robot) --authfile=./pull-secret.json
oc adm release mirror -a ./pull-secret.json --from="$OPENSHIFT_RELEASE_IMAGE" --to-release-image="${LOCAL_REG}"/ocp4/openshift4:"${OCP_RELEASE}" --to="${LOCAL_REG}"/ocp4/openshift4
#oc logout ; oc config use-context admin

echo ">>>>EOF"
echo ">>>>>>>"


