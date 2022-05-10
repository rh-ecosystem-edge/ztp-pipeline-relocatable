#!/usr/bin/env bash
# Description: Renders workers YAML into different files for each edgecluster cluster

set -o pipefail
set -o nounset
set -m

create_worker_definitions() {
    local cluster=${1}
    local edgeclusternumber=${2}

    # Set vars
    export CHANGE_EDGE_NAME=${cluster}

    # Generic vars for all workers
    export CHANGE_EDGE_WORKER_PUB_INT_MASK=24
    export CHANGE_EDGE_WORKER_PUB_INT_GW=192.168.7.1
    export CHANGE_EDGE_WORKER_PUB_INT_ROUTE_DEST=192.168.7.0/24

    # Get our edgecluster index number for the following loops
    RESULT=$(yq eval ".edgeclusters[${edgeclusternumber}]" ${EDGECLUSTERS_FILE})

    # Now process blocks for each worker (only one at the moment)
    echo ">> Detecting number of workers"
    NUM_W=$(yq e ".edgeclusters[${edgeclusternumber}].[]|keys" ${EDGECLUSTERS_FILE} | grep worker | wc -l | xargs)
    echo ">> Workers: ${NUM_W}"
    NUM_W=$((NUM_W - 1))

    for worker in $(seq 0 ${NUM_W}); do
        export CHANGE_EDGE_WORKER_PUB_INT=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.nic_int_static" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_WORKER_MGMT_INT=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.nic_ext_dhcp" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_WORKER_PUB_INT_IP=192.168.7.13
        export EDGE_MASTER_0_INT_IP=192.168.7.10
        export CHANGE_EDGE_WORKER_PUB_INT_MAC=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.mac_int_static" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_WORKER_BMC_USERNAME=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.bmc_user" ${EDGECLUSTERS_FILE} | base64)
        export CHANGE_EDGE_WORKER_BMC_PASSWORD=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.bmc_pass" ${EDGECLUSTERS_FILE} | base64)
        export CHANGE_EDGE_WORKER_BMC_URL=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.bmc_url" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_WORKER_MGMT_INT_MAC=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_WORKER_ROOT_DISK=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.worker${worker}.root_disk" ${EDGECLUSTERS_FILE})

        # Now, write the template to disk
        OUTPUT="${OUTPUTDIR}/${cluster}-worker${worker}.yaml"
        echo ">> Rendering Worker ${worker}: ${OUTPUT}"

        cat <<EOF >${OUTPUT}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
 name: ztpfw-${cluster}-worker-${worker}
 namespace: $CHANGE_EDGE_NAME
 labels:
   nmstate_config_cluster_name: $CHANGE_EDGE_NAME
spec:
 config:
   interfaces:
     - name: $CHANGE_EDGE_WORKER_MGMT_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 10000
       ipv4:
         enabled: true
         dhcp: true
         auto-dns: false
         auto-gateway: true
         auto-routes: true
       mtu: 1500
     - name: $CHANGE_EDGE_WORKER_PUB_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 1000
       ipv4:
         enabled: true
         address:
           - ip: $CHANGE_EDGE_WORKER_PUB_INT_IP
             prefix-length: $CHANGE_EDGE_WORKER_PUB_INT_MASK
       mtu: 1500
       mac-address: '$CHANGE_EDGE_WORKER_PUB_INT_MAC'
   dns-resolver:
     config:
       server:
         - $EDGE_MASTER_0_INT_IP
   routes:
     config:
       - destination: $CHANGE_EDGE_WORKER_PUB_INT_ROUTE_DEST
         next-hop-address: $CHANGE_EDGE_WORKER_PUB_INT_GW
         next-hop-interface: $CHANGE_EDGE_WORKER_PUB_INT
 interfaces:
   - name: "$CHANGE_EDGE_WORKER_MGMT_INT"
     macAddress: '$CHANGE_EDGE_WORKER_MGMT_INT_MAC'
   - name: "$CHANGE_EDGE_WORKER_PUB_INT"
     macAddress: '$CHANGE_EDGE_WORKER_PUB_INT_MAC'
---
apiVersion: v1
kind: Secret
metadata:
 name: 'ztpfw-${cluster}-worker-${worker}-bmc-secret'
 namespace: '$CHANGE_EDGE_NAME'
type: Opaque
data:
 username: '$CHANGE_EDGE_WORKER_BMC_USERNAME'
 password: '$CHANGE_EDGE_WORKER_BMC_PASSWORD'
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
 name: 'ztpfw-${cluster}-worker-${worker}'
 namespace: '$CHANGE_EDGE_NAME'
 labels:
   infraenvs.agent-install.openshift.io: '$CHANGE_EDGE_NAME'
 annotations:
   inspect.metal3.io: disabled
   bmac.agent-install.openshift.io/hostname: 'ztpfw-${cluster}-worker-${worker}'
   bmac.agent-install.openshift.io/role: worker
spec:
 online: false
 bootMACAddress: '$CHANGE_EDGE_WORKER_MGMT_INT_MAC'
 rootDeviceHints:
   deviceName: '$CHANGE_EDGE_WORKER_ROOT_DISK'
 bmc:
   disableCertificateVerification: true
   address: '$CHANGE_EDGE_WORKER_BMC_URL'
   credentialsName: 'ztpfw-${cluster}-worker-${worker}-bmc-secret'

EOF

        echo ">>>> Deploying BMH Worker ${worker} for ${1}"
        oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${OUTPUT}
    done
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

# Check first item only
RESULT=$(yq eval ".edgeclusters[0]" ${EDGECLUSTERS_FILE})

if [ "${RESULT}" == "null" ]; then
    echo "Couldn't evaluate name of first edgecluster in YAML at $EDGECLUSTERS_FILE, please check and retry"
    exit 1
fi

if [[ -z ${ALLEDGECLUSTERS} ]]; then
    ALLEDGECLUSTERS=$(yq e '(.edgeclusters[] | keys)[]' ${EDGECLUSTERS_FILE})
fi

index=0

for EDGE in ${ALLEDGECLUSTERS}; do
    create_worker_definitions ${EDGE} ${index}
    WORKER_AGENT=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${EDGE} --no-headers | grep worker | cut -f1 -d\ )
    check_resource "agent" "${WORKER_AGENT}" "Installed" "${EDGE}" "${KUBECONFIG_HUB}"
    index=$((index + 1))
done
