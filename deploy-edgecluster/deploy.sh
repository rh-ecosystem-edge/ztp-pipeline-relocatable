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

    cd ${OUTPUTDIR}
    oc apply -k .
    if [[ -z ${ALLEDGECLUSTERS} ]]; then
        ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
    fi
    
    index=0
    
    for cluster in ${ALLEDGECLUSTERS}; do
        echo "Storing the RSA key on the hub for cluster ${cluster}"
        export RSA_KEY_FILE="${WORKDIR}/${cluster}/${cluster}-rsa.key"
        export RSA_PUB_FILE="${WORKDIR}/${cluster}/${cluster}-rsa.key.pub"
        oc --kubeconfig=${KUBECONFIG_HUB} -n ${cluster} create secret generic ${cluster}-keypair --from-file=id_rsa.key=${RSA_KEY_FILE} --from-file=id_rsa.pub=${RSA_PUB_FILE}
        index=$((index + 1))
    done

    oc patch provisioning provisioning-configuration --type merge -p '{"spec":{"watchAllNamespaces": true}}'

    echo "Verifying again the clusterDeployment"
    # Waiting for 166 min to have the cluster deployed
    ${WORKDIR}/${DEPLOY_EDGECLUSTERS_DIR}/verify.sh 10000
else
    echo ">> Cluster deployed, this step is not neccessary"
    exit 0
fi
