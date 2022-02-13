#!/bin/bash

oc new-project kubeframe-ui

set -ex

cd scripts

# TODO: make this optional
#./createTlsSecret.sh

export IMAGE=quay.io\\/mlibra\\/kubeframe:latest
export ROUTE_HOST=kubeframe.apps.mlibra-cim-04.redhat.com
export APP_URL=https:\\/\\/${ROUTE_HOST}
export NAMESPACE=kubeframe-ui

# TODO: parametrize following resources, i.e. for cluster address
#oc apply -f deployment.yaml
cat deployment.yaml | \
  sed "s/___NAMESPACE___/${NAMESPACE}/g" | \
  sed "s/___IMAGE___/${IMAGE}/g" | \
  sed "s/___ROUTE_HOST___/${ROUTE_HOST}/g" | \
  sed "s/___APP_URL___/${APP_URL}/g" | \
  oc apply -f -

### Restart the pod - just to be sure, i.e. TLS could be changed
oc delete pod `oc get pods |grep kubeframe-ui|awk '{print $1}' -`
oc get pods

