#!/usr/bin/env bash

export REGISTRY_NAME=$(hostname --long)
export REGISTRY_USER=dummy
export REGISTRY_PASS=dummy

echo "Original values:"
echo "Registry Name: ${REGISTRY_NAME}"
echo "Registry User: ${REGISTRY_USER}"
echo "Registry Pass: ${REGISTRY_PASS}"
echo
echo "creating the pull secret entry"
b64auth=$( echo -n "$REGISTRY_USER:$REGISTRY_PASS" | base64 )
AUTHSTRING="{\"$REGISTRY_NAME:5000\": {\"auth\": \"$b64auth\"}}"
echo

echo "getting pull secret"
oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d > origin-pullsecret.json
echo
echo "Creating updated pull secret"
jq ".auths += $AUTHSTRING" < origin-pullsecret.json > updated-pull-secret.json
echo
echo "the new pull secret before pushing to openshift config:"
cat updated-pull-secret.json
echo
echo "pushing openshift config"
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=updated-pull-secret.json