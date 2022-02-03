#!/bin/bash

oc new-project kubeframe-ui

set -ex

cd scripts
./createTlsSecret.sh

oc apply -f oauthclient.yaml
oc apply -f deployment.yaml
oc apply -f service.yaml
oc apply -f route.yaml

### Restart the pod - just to be sure, i.e. TLS could be changed
oc delete pod `oc get pods |grep kubeframe-ui|awk '{print $1}' -`
oc get pods

