#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig   
export KUBECONFIG="$OC_KUBECONFIG_PATH"

domain=$(grep server kubeconfig | awk '{print $2}' | cut -d '.' -f 2- | cut -d ':' -f 1)
sed -i "s/CHANGEDOMAIN/$domain/g" http-server.yml

oc create -f http-server.yml; sleep 2

echo ">>>>EOF"
echo ">>>>>>>"


