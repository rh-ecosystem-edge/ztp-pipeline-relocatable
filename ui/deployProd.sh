#!/bin/bash
# Let following silently fail if the project already exists
oc new-project ztpfw-ui

echo Parameters:
set -ex
export EDGE_INGRESS_NAME=$(oc get ingresses.config.openshift.io cluster -o json| jq -j .spec.domain)
export UI_NS=ztpfw-ui
export UI_IMAGE="quay.io\\/ztpfw\\/ui:latest"
export UI_ROUTE_HOST="edge-cluster-setup.${EDGE_INGRESS_NAME}"
export UI_APP_URL="https:\\/\\/${UI_ROUTE_HOST}"

echo ${UI_NS}
echo ${UI_IMAGE}
echo ${EDGE_INGRESS_NAME}
echo ${UI_ROUTE_HOST}
echo ${UI_APP_URL}

rm -f ./deploy.yaml
for FILE in clusterrolbinding.yaml deployment.yaml oauth-client.yaml route.yaml service.yaml ; do
  cat ../deploy-ui/manifests/$FILE >> ./deploy.yaml
done

cat ./deploy.yaml |
    sed -e "s/\$UI_NS/${UI_NS}/g" |
    sed -e "s/\$UI_IMAGE/${UI_IMAGE}/g" |
    sed -e "s/\$UI_ROUTE_HOST/${UI_ROUTE_HOST}/g" |
    sed -e "s/\$UI_APP_URL/${UI_APP_URL}/g"  |
    oc apply -f -

### Restart the pod - just to be sure, i.e. TLS could be changed
oc delete pod $(oc get pods | grep ztpfw-ui | awk '{print $1}' -)
oc get pods

echo Do not forget to deploy CRDS via scripts/applyCrds.sh
