#!/bin/bash
# Description: Renders clusters yaml into different files for each spoke cluster

set -o errexit
set -o pipefail
set -o nounset
set -m

# Path to read YAML from (change to $1 in production)
YAML=${1}

if [ ! -f "${YAML}" ]; then
  echo "File ${YAML} does not exist"
  exit 1
fi

# Store alongside Kubeconfig
OUTPUT_DIR=$(dirname ${KUBECONFIG})

# Prepare loop for spokes
i=0

# Check first item
RESULT=$(yq eval ".spokes[$i]" ${YAML})

if [ "${RESULT}" == "null" ]; then
	echo "Couldn't evaluate name of first spoke in YAML at $YAML, please check and retry"
	exit 1
fi

while [ "${RESULT}" != "null" ]; do
	SPOKE_NAME=$(echo $RESULT | cut -d ":" -f 1)
	OUTPUT="${OUTPUT_DIR}/${SPOKE_NAME}.sh"

    # Empty output file for safety
    echo ""> ${OUTPUT}
    cat <<EOF >>${OUTPUT}
export CHANGE_SPOKE_NAME=${SPOKE_NAME} # from input spoke-file
export CHANGE_SPOKE_PULL_SECRET_NAME=pull-secret-spoke-cluster
export CHANGE_PULL_SECRET=$(oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
export CHANGE_SPOKE_CLUSTERIMAGESET=openshift-v4.9.0
export CHANGE_SPOKE_API=192.168.7.243
export CHANGE_SPOKE_INGRESS=192.168.7.242
export CHANGE_SPOKE_CLUSTER_NET_PREFIX=23
export CHANGE_SPOKE_CLUSTER_NET_CIDR=172.30.0.0/16
export CHANGE_SPOKE_SVC_NET_CIDR=172.30.0.0/16
export CHANGE_RSA_PUB_KEY=~/.ssh/id_rsa.pub
#export CHANGE_SPOKE_DNS= # hub ip or name ???
EOF

    # Now process blocks for each master
    for master in 0 1 2; do
        cat <<EOF >>${OUTPUT}

# Master loop
export CHANGE_SPOKE_MASTER_${master}_MGMT_INT=eno4
export CHANGE_SPOKE_MASTER_${master}_PUB_INT=eno5
export CHANGE_SPOKE_MASTER_${master}_PUB_INT_IP=192.168.7.1${master}
export CHANGE_SPOKE_MASTER_${master}_PUB_INT_MASK=16
export CHANGE_SPOKE_MASTER_${master}_PUB_INT_GW=192.168.7.1
export CHANGE_SPOKE_MASTER_${master}_PUB_INT_ROUTE_DEST=192.168.7.0/24

export CHANGE_SPOKE_MASTER_${master}_PUB_INT_MAC=$(yq eval ".spokes[$i].master$master.mac" ${YAML})
export CHANGE_SPOKE_MASTER_${master}_BMC_USERNAME=$(yq eval ".spokes[$i].master$master.bmc_user" ${YAML})
export CHANGE_SPOKE_MASTER_${master}_BMC_PASSWORD=$(yq eval ".spokes[$i].master$master.bmc_pass" ${YAML})
export CHANGE_SPOKE_MASTER_${master}_BMC_URL=$(yq eval ".spokes[$i].master$master.bmc_url" ${YAML})
EOF
done

	# Prepare for next loop
	i=$((i + 1))
	RESULT=$(yq eval ".spokes[${i}]" ${YAML})
done
