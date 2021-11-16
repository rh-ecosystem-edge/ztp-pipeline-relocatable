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
OPENSHIFT_RELEASE_IMAGE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.image'})
OCP_RELEASE=$(oc get clusterversion -o jsonpath={'.items[0].status.desired.version'})-x86_64
LOCAL_REG=$(oc get route -n openshift-image-registry | awk '{print $2}' | tail -1)

oc adm release mirror -a ./pull-secret.json --from="$OPENSHIFT_RELEASE_IMAGE" --to-release-image="${LOCAL_REG}"/ocp4:"${OCP_RELEASE}" --to="${LOCAL_REG}"/ocp4

echo ">>>>EOF"
echo ">>>>>>>"


