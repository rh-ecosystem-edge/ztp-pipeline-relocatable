#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
source ./common.sh ${1}

echo ">>>> Enable internal registry"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
sleep 10
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":null}}}}'
sleep 10
oc patch configs.imageregistry.operator.openshift.io/cluster --type=merge --patch '{"spec":{"defaultRoute":true}}'
sleep 60

echo ">>>> Trusting internal registry"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
## Update trusted CA from Helper
oc --kubeconfig=${KUBECONFIG_HUB} get secret -n openshift-ingress router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d >/etc/pki/ca-trust/source/anchors/internal-registry.crt
update-ca-trust extract
