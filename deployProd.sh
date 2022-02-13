#!/bin/bash
export IMAGE=${IMAGE:-"quay.io\\/mlibra\\/kubeframe:latest"}
export ROUTE_HOST=${ROUTE_HOST:-"kubeframe.apps.mlibra-cim-04.redhat.com"}
export NAMESPACE=${NAMESPACE:-"kubeframe-ui"}

export APP_URL=https:\\/\\/${ROUTE_HOST}

cd scripts

# Let following silently fail if the project already exists
oc new-project kubeframe-ui

echo Parameters:
set -ex
echo ${IMAGE}
echo ${ROUTE_HOST}
echo ${NAMESPACE}
echo ${APP_URL}

./createTlsSecret.sh

cat deployment.yaml | \
  sed "s/___NAMESPACE___/${NAMESPACE}/g" | \
  sed "s/___IMAGE___/${IMAGE}/g" | \
  sed "s/___ROUTE_HOST___/${ROUTE_HOST}/g" | \
  sed "s/___APP_URL___/${APP_URL}/g" | \
  oc apply -f -

### Restart the pod - just to be sure, i.e. TLS could be changed
oc delete pod `oc get pods |grep kubeframe-ui|awk '{print $1}' -`
oc get pods

