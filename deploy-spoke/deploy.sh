#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

if ! ./verify.sh 1; then
    echo ">>>> Deploy all the manifests using kustomize"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'

    cd ${OUTPUTDIR}
    oc apply -k .

    echo "Verifying again the clusterDeployment"
    # Waiting for 166 min to have the cluster deployed
    ${WORKDIR}/${DEPLOY_SPOKES_DIR}/verify.sh 10000
else
    echo ">> Cluster deployed, this step is not neccessary"
    exit 0
fi
