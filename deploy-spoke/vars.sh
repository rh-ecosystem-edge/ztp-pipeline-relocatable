#!/bin/bash

# spoke-cluster-1
export CHANGE_SPOKE_NAME=$(yq r spokes.yaml spokes.spoke1)  # from input spoke-file
export CHANGE_SPOKE_PULL-SECRET_NAME=pull-secret-spoke-cluster
export CHANGE_PULL_SECRET=$(oc get secret -n openshift-config pull-secret -ojsonpath='{.data.\.dockerconfigjson}' | base64 -d)
export CHANGE_SPOKE_CLUSTERIMAGESET=openshift-v4.9.0
export CHANGE_SPOKE_API=192.168.7.243
export CHANGE_SPOKE_INGRESS=192.168.7.242
export CHANGE_SPOKE_CLUSTER-NET-PREFIX=23
export CHANGE_SPOKE_CLUSTER-NET-CIDR=172.30.0.0/16
export CHANGE_SPOKE_SVC-NET-CIDR=172.30.0.0/16
export CHANGE_RSA_PUB_KEY=~/.ssh/id_rsa.pub
export CHANGE_SPOKE_DNS=   # hub ip or name ???

# Master-0
export CHANGE_SPOKE-MASTER-0_MGMT-INT=eno4 # dhcp remove from here
export CHANGE_SPOKE-MASTER-0_MGMT-INT_MAC= # dhcp remove from here
export CHANGE_SPOKE-MASTER-0_MGMT-INT_IP=192.168.20.10 #dhcp remove from here
export CHANGE_SPOKE-MASTER-0_MGMT-INT_MASK=16 #dhcp remove from here
export CHANGE_SPOKE-MASTER-0_MGMT-INT_GW=192.168.20.1 #dhcp remove from here 
export CHANGE_SPOKE-MASTER-0_MGMT-INT_ROUTE_DEST=0.0.0.0/0  # dhcp remove from here
export CHANGE_SPOKE-MASTER-0_PUB-INT=eno5              #eno5 no eno1
export CHANGE_SPOKE-MASTER-0_PUB-INT_MAC=$(yq r spokes.yaml spokes.spoke1.master0.mac)        
export CHANGE_SPOKE-MASTER-0_PUB-INT_IP=192.168.7.10
export CHANGE_SPOKE-MASTER-0_PUB-INT_MASK=16
export CHANGE_SPOKE-MASTER-0_PUB-INT_GW=192.168.7.1
export CHANGE_SPOKE-MASTER-0_PUB-INT_ROUTE_DEST=192.168.7.0/24
export CHANGE_SPOKE-MASTER-0_BMC_USERNAME=$(yq r spokes.yaml spokes.spoke1.master0.bmc_user)
export CHANGE_SPOKE-MASTER-0_BMC_PASSWORD=$(yq r spokes.yaml spokes.spoke1.master0.bmc_pass)
#CHANGE_SPOKE-MASTER-0_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1
export CHANGE_SPOKE-1-MASTER-0_BMC_URL=$(yq r spokes.yaml spokes.spoke1.master0.bmc_url)

# Master-1
export CHANGE_SPOKE-MASTER-1_MGMT-INT=eno4 # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_MGMT-INT_MAC=XXXX # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_MGMT-INT_IP=192.168.20.11 # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_MGMT-INT_MASK=16 # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_MGMT-INT_GW=192.168.20.1 # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_MGMT-INT_ROUTE_DEST=0.0.0.0/0  # dhcp remove from here
export CHANGE_SPOKE-MASTER-1_PUB-INT=eno5 
export CHANGE_SPOKE-MASTER-1_PUB-INT_MAC=$(yq r spokes.yaml spokes.spoke1.master1.mac)
export CHANGE_SPOKE-MASTER-1_PUB-INT_IP=192.168.7.11
export CHANGE_SPOKE-MASTER-1_PUB-INT_MASK=16
export CHANGE_SPOKE-MASTER-1_PUB-INT_GW=192.168.7.1
export CHANGE_SPOKE-MASTER-1_PUB-INT_ROUTE_DEST=192.168.7.0/24
export CHANGE_SPOKE-MASTER-1_BMC_USERNAME=$(yq r spokes.yaml spokes.spoke1.master1.bmc_user)
export CHANGE_SPOKE-MASTER-1_BMC_PASSWORD=$(yq r spokes.yaml spokes.spoke1.master1.bmc_pass)
#CHANGE_SPOKE-MASTER-1_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1
export CHANGE_SPOKE-MASTER-1_BMC_URL=$(yq r spokes.yaml spokes.spoke1.master1.bmc_url)

# Master-2
export CHANGE_SPOKE-MASTER-2_MGMT-INT=eno4 # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_MGMT-INT_MAC=XXXX # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_MGMT-INT_IP=192.168.20.12 # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_MGMT-INT_MASK=16 # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_MGMT-INT_GW=192.168.20.1 # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_MGMT-INT_ROUTE_DEST=0.0.0.0/0 # dhcp remove from here
export CHANGE_SPOKE-MASTER-2_PUB-INT=eno5 
export CHANGE_SPOKE-MASTER-2_PUB-INT_MAC=$(yq r spokes.yaml spokes.spoke1.master2.mac)
export CHANGE_SPOKE-MASTER-2_PUB-INT_IP=192.168.7.12
export CHANGE_SPOKE-MASTER-2_PUB-INT_MASK=16 
export CHANGE_SPOKE-MASTER-2_PUB-INT_GW=192.168.7.1
export CHANGE_SPOKE-MASTER-2_PUB-INT_ROUTE_DEST=192.168.7.0/24
export CHANGE_SPOKE-MASTER-2_BMC_USERNAME=$(yq r spokes.yaml spokes.spoke1.master2.bmc_user)
export CHANGE_SPOKE-MASTER-2_BMC_PASSWORD=$(yq r spokes.yaml spokes.spoke1.master2.bmc_pass)
#CHANGE_SPOKE-MASTER-2_BMC_URL=redfish-virtualmedia+https://192.168.10.12/redfish/v1/Systems/1
export CHANGE_SPOKE-MASTER-2_BMC_URL=$(yq r spokes.yaml spokes.spoke1.master2.bmc_pass)
