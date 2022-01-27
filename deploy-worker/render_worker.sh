#!/bin/bash
# Description: Renders workers YAML into different files for each spoke cluster

set -o pipefail
set -o nounset
set -m

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

# Check first item only
RESULT=$(yq eval ".spokes[0]" ${SPOKES_FILE})

if [ "${RESULT}" == "null" ]; then
    echo "Couldn't evaluate name of first spoke in YAML at $SPOKES_FILE, please check and retry"
    exit 1
fi

create_worker_definitions() {

    SPOKE_NAME=${1}
    # Set vars
    export CHANGE_SPOKE_NAME=${SPOKE_NAME} # from input spoke-file

    # Generic vars for all workers
    export CHANGE_SPOKE_WORKER_PUB_INT_MASK=24
    export CHANGE_SPOKE_WORKER_PUB_INT_GW=192.168.7.1
    export CHANGE_SPOKE_WORKER_PUB_INT_ROUTE_DEST=192.168.7.0/24

    # Get our spoke index number for the following loops
    loop=0
    RESULT=$(yq eval ".spokes[${loop}]" ${SPOKES_FILE})
    while [ "${RESULT}" != "null" ]; do

        LOOP_SPOKE_NAME=$(echo $RESULT | cut -d ":" -f 1)

        if [ "${LOOP_SPOKE_NAME}" == "${SPOKE_NAME}" ]; then
            export i=${loop}
            break
        fi
        loop=$((loop + 1))
        RESULT=$(yq eval ".spokes[${loop}]" ${SPOKES_FILE})

    done

    # Now process blocks for each worker (only one at the moment)
    worker=0

    # Master loop
    export CHANGE_SPOKE_WORKER_PUB_INT=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.nic_int_static" ${SPOKES_FILE})
    export CHANGE_SPOKE_WORKER_MGMT_INT=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.nic_ext_dhcp" ${SPOKES_FILE})
    export CHANGE_SPOKE_WORKER_PUB_INT_IP=192.168.7.13
    export SPOKE_MASTER_0_INT_IP=192.168.7.10
    export CHANGE_SPOKE_WORKER_PUB_INT_MAC=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.mac_int_static" ${SPOKES_FILE})
    export CHANGE_SPOKE_WORKER_BMC_USERNAME=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.bmc_user" ${SPOKES_FILE} | base64)
    export CHANGE_SPOKE_WORKER_BMC_PASSWORD=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.bmc_pass" ${SPOKES_FILE} | base64)
    export CHANGE_SPOKE_WORKER_BMC_URL=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.bmc_url" ${SPOKES_FILE})
    export CHANGE_SPOKE_WORKER_MGMT_INT_MAC=$(yq eval ".spokes[${i}].${SPOKE_NAME}.worker${worker}.mac_ext_dhcp" ${SPOKES_FILE})

    # Now, write the template to disk
    OUTPUT="${OUTPUTDIR}/spoke-${i}-worker${worker}.yaml"

    cat <<EOF >${OUTPUT}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
 name: kubeframe-spoke-${i}-worker-${worker}
 namespace: $CHANGE_SPOKE_NAME
 labels:
   nmstate_config_cluster_name: $CHANGE_SPOKE_NAME
spec:
 config:
   interfaces:
     - name: $CHANGE_SPOKE_WORKER_MGMT_INT
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
     - name: $CHANGE_SPOKE_WORKER_PUB_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 1000
       ipv4:
         enabled: true
         address:
           - ip: $CHANGE_SPOKE_WORKER_PUB_INT_IP
             prefix-length: $CHANGE_SPOKE_WORKER_PUB_INT_MASK
       mtu: 1500
       mac-address: '$CHANGE_SPOKE_WORKER_PUB_INT_MAC'
   dns-resolver:
     config:
       server:
         - $SPOKE_MASTER_0_INT_IP
   routes:
     config:
       - destination: $CHANGE_SPOKE_WORKER_PUB_INT_ROUTE_DEST
         next-hop-address: $CHANGE_SPOKE_WORKER_PUB_INT_GW
         next-hop-interface: $CHANGE_SPOKE_WORKER_PUB_INT
 interfaces:
   - name: "$CHANGE_SPOKE_WORKER_MGMT_INT"
     macAddress: '$CHANGE_SPOKE_WORKER_MGMT_INT_MAC'
   - name: "$CHANGE_SPOKE_WORKER_PUB_INT"
     macAddress: '$CHANGE_SPOKE_WORKER_PUB_INT_MAC'
---
apiVersion: v1
kind: Secret
metadata:
 name: 'kubeframe-spoke-${i}-worker-${worker}-bmc-secret'
 namespace: '$CHANGE_SPOKE_NAME'
type: Opaque
data:
 username: '$CHANGE_SPOKE_WORKER_BMC_USERNAME'
 password: '$CHANGE_SPOKE_WORKER_BMC_PASSWORD'
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
 name: 'kubeframe-spoke-${i}-worker-${worker}'
 namespace: '$CHANGE_SPOKE_NAME'
 labels:
   infraenvs.agent-install.openshift.io: '$CHANGE_SPOKE_NAME'
 annotations:
   inspect.metal3.io: disabled
   bmac.agent-install.openshift.io/hostname: 'kubeframe-spoke-${i}-worker-${worker}'
   bmac.agent-install.openshift.io/role: worker
spec:
 online: false
 bootMACAddress: '$CHANGE_SPOKE_WORKER_MGMT_INT_MAC'
 rootDeviceHints:
   deviceName: /dev/sda
 bmc:
   disableCertificateVerification: true
   address: '$CHANGE_SPOKE_WORKER_BMC_URL'
   credentialsName: 'kubeframe-spoke-${i}-worker-${worker}-bmc-secret'

EOF

    echo ">>>> Deploying BMH Worker for ${1}"
    oc --kubeconfig=${KUBECONFIG_HUB} apply -f ${OUTPUT}

}

function verify_worker() {

    cluster=${1}
    timeout=0
    ready=false

    echo ">>>> Waiting for Worker Agent: ${cluster}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    while [ "$timeout" -lt "600" ]; do
        WORKER_AGENT=$(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${cluster} --no-headers | grep worker | cut -f1 -d\ )
        echo "Waiting for Worker's agent installation for spoke: ${cluster} - Agent: ${WORKER_AGENT}"
        if [[ $(oc --kubeconfig=${KUBECONFIG_HUB} get agent -n ${cluster} ${WORKER_AGENT} -o jsonpath='{.status.conditions[?(@.reason=="InstallationCompleted")].status}') == True ]]; then
            ready=true
            break
        fi
        sleep 5
        timeout=$((timeout + 1))
    done

    if [ "$ready" == "false" ]; then
        echo "Timeout waiting for Worker's agent installation for spoke: ${cluster}"
        exit 1
    fi

}

# Main code
if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for SPOKE in ${ALLSPOKES}; do
    create_worker_definitions ${SPOKE}
    verify_worker ${SPOKE}
done
