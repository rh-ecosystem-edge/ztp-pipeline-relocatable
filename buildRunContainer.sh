#!/bin/bash

podman build . -f Dockerfile -t kubeframe:test

# At runtime, expected to be in: /var/run/secrets/kubernetes.io/serviceaccount
export TOKEN=`oc whoami -t`
export CLUSTER_API_URL=`oc whoami --show-server=true`
podman run -t -p 3001:3001/tcp --env CLUSTER_API_URL --env TOKEN kubeframe:test

