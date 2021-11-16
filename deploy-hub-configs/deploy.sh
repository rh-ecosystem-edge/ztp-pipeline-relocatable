#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig 


echo ">>>> Deploy AI over ACM"
echo ">>>>>>>>>>>>>>>>>>>>>>>"

sed -i "s%TAG_OCP_IMAGE_RELEASE%$OC_OCP_VERSION%g" 02-cluster_imageset.yml
sed -i "s/CHANGEME/$OC_RHCOS_RELEASE/g" 04-agent-service-config.yml
httpservice=$(oc get routes -n default|grep httpd-server-route|awk '{print $2}')
sed -i "s/HTTPD_SERVICE/$httpservice/g" 04-agent-service-config.yml
pull=$(oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
sed -i "s/PULL_SECRET/$pull/g" 05-pullsecrethub.yml


cert del registry: oc get secret -n openshift-ingress  router-certs-default -o go-template='{{index .data "tls.crt"}}' | base64 -d | sudo tee /etc/pki/ca-trust/source/anchors/${HOST}.crt 
 


echo ">>>> Wait for ACM and AI deployed successfully"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
while [[ $(oc get pod -n open-cluster-management | grep assisted | wc -l) -eq 0 ]]; do
    echo "Waiting for Assisted installer to be ready..."
    sleep 5
done
../"$SHARED_DIR"/wait_for_deployment.sh -t 1000 -n open-cluster-management assisted-service


echo ">>>>EOF"
echo ">>>>>>>"


