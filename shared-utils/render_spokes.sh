#!/bin/bash
# Description: Renders clusters yaml into different files for each spoke cluster

set -o errexit
set -o pipefail
set -o nounset
set -m

# Path to read YAML from (change to $1 in production)
YAML=/home/iranzo/DEVEL/RH/syseng/MINT/ztp-pipeline-relocatable/examples/spokes.yaml

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
	OUTPUT="${OUTPUT_DIR}/${SPOKE_NAME}.yml"

	cat <<EOF >${OUTPUT}
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
export CHANGE_SPOKE_DNS= # hub ip or name ???

# Master-0
export CHANGE_SPOKE_MASTER_0_MGMT_INT=eno4             # dhcp remove from here
export CHANGE_SPOKE_MASTER_0_MGMT_INT_MAC=             # dhcp remove from here
export CHANGE_SPOKE_MASTER_0_MGMT_INT_IP=192.168.20.10 #dhcp remove from here
export CHANGE_SPOKE_MASTER_0_MGMT_INT_MASK=16          #dhcp remove from here
export CHANGE_SPOKE_MASTER_0_MGMT_INT_GW=192.168.20.1 #dhcp remove from here
export CHANGE_SPOKE_MASTER_0_MGMT_INT_ROUTE_DEST=0.0.0.0/0 # dhcp remove from here
export CHANGE_SPOKE_MASTER_0_PUB_INT=eno5                  #eno5 no eno1
export CHANGE_SPOKE_MASTER_0_PUB_INT_IP=192.168.7.10
export CHANGE_SPOKE_MASTER_0_PUB_INT_MASK=16
export CHANGE_SPOKE_MASTER_0_PUB_INT_GW=192.168.7.1
export CHANGE_SPOKE_MASTER_0_PUB_INT_ROUTE_DEST=192.168.7.0/24
#CHANGE_SPOKE-MASTER-0_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1

export CHANGE_SPOKE_MASTER_0_PUB_INT_MAC=$(yq eval ".spokes[0].master0.mac" ${YAML})
export CHANGE_SPOKE_MASTER_0_BMC_USERNAME=$(yq eval ".spokes[0].master0.bmc_user" ${YAML})
export CHANGE_SPOKE_MASTER_0_BMC_PASSWORD=$(yq eval ".spokes[0].master0.bmc_pass" ${YAML})
export CHANGE_SPOKE_MASTER_0_BMC_URL=$(yq eval ".spokes[0].master0.bmc_url" ${YAML})

# Master-1
export CHANGE_SPOKE_MASTER_1_MGMT_INT=eno4                 # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_MGMT_INT_MAC=XXXX             # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_MGMT_INT_IP=192.168.20.11     # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_MGMT_INT_MASK=16              # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_MGMT_INT_GW=192.168.20.1      # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_MGMT_INT_ROUTE_DEST=0.0.0.0/0 # dhcp remove from here
export CHANGE_SPOKE_MASTER_1_PUB_INT=eno5
export CHANGE_SPOKE_MASTER_1_PUB_INT_IP=192.168.7.11
export CHANGE_SPOKE_MASTER_1_PUB_INT_MASK=16
export CHANGE_SPOKE_MASTER_1_PUB_INT_GW=192.168.7.1
export CHANGE_SPOKE_MASTER_1_PUB_INT_ROUTE_DEST=192.168.7.0/24
#CHANGE_SPOKE-MASTER-1_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1


export CHANGE_SPOKE_MASTER_1_PUB_INT_MAC=$(yq eval ".spokes[0].master1.mac" ${YAML})
export CHANGE_SPOKE_MASTER_1_BMC_USERNAME=$(yq eval ".spokes[0].master1.bmc_user" ${YAML})
export CHANGE_SPOKE_MASTER_1_BMC_PASSWORD=$(yq eval ".spokes[0].master1.bmc_pass" ${YAML})
export CHANGE_SPOKE_MASTER_1_BMC_URL=$(yq eval ".spokes[0].master1.bmc_url" ${YAML})



# Master-2
export CHANGE_SPOKE_MASTER_2_MGMT_INT=eno4                 # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_MGMT_INT_MAC=XXXX             # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_MGMT_INT_IP=192.168.20.12     # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_MGMT_INT_MASK=16              # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_MGMT_INT_GW=192.168.20.1      # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_MGMT_INT_ROUTE_DEST=0.0.0.0/0 # dhcp remove from here
export CHANGE_SPOKE_MASTER_2_PUB_INT=eno5
export CHANGE_SPOKE_MASTER_2_PUB_INT_IP=192.168.7.12
export CHANGE_SPOKE_MASTER_2_PUB_INT_MASK=16
export CHANGE_SPOKE_MASTER_2_PUB_INT_GW=192.168.7.1
export CHANGE_SPOKE_MASTER_2_PUB_INT_ROUTE_DEST=192.168.7.0/24
#CHANGE_SPOKE-MASTER-2_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1

export CHANGE_SPOKE_MASTER_2_PUB_INT_MAC=$(yq eval ".spokes[0].master2.mac" ${YAML})
export CHANGE_SPOKE_MASTER_2_BMC_USERNAME=$(yq eval ".spokes[0].master2.bmc_user" ${YAML})
export CHANGE_SPOKE_MASTER_2_BMC_PASSWORD=$(yq eval ".spokes[0].master2.bmc_pass" ${YAML})
export CHANGE_SPOKE_MASTER_2_BMC_URL=$(yq eval ".spokes[0].master2.bmc_url" ${YAML})

EOF

	# Prepare for next loop
	i=$((i + 1))
	RESULT=$(yq eval ".spokes[${i}]" ${YAML})
done
