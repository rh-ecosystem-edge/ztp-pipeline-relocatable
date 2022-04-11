#!/usr/bin/env bash
# Description: Renders clusters YAML into different files for each spoke cluster

set -o pipefail
set -o nounset
set -m

create_kustomization() {
    # Loop for spokes
    # Prepare loop for spokes
    local cluster=${1}
    local spokenumber=${2}

    # Pregenerate kustomization.yaml and spoke cluster config
    OUTPUT="${OUTPUTDIR}/kustomization.yaml"

    # Write header
    echo "resources:" >${OUTPUT}

    echo ">> Detecting number of masters"
    NUM_M=$(yq e ".spokes[${spokenumber}].[]|keys" ${SPOKES_FILE} | grep master | wc -l | xargs)
    echo ">> Masters: ${NUM_M}"
    NUM_M=$((NUM_M - 1))

    echo ">> Rendering Kustomize for: ${cluster}"
    for node in $(seq 0 ${NUM_M}); do
        echo "  - ${cluster}-master-${node}.yaml" >>${OUTPUT}
    done
    echo "  - ${cluster}-cluster.yaml" >>${OUTPUT}
}

create_spoke_definitions() {
    # Reset loop for spoke general definition
    local cluster=${1}
    local spokenumber=${2}

    # Generic vars for all spokes
    export CHANGE_SPOKE_PULL_SECRET_NAME=pull-secret-spoke-cluster
    export CHANGE_PULL_SECRET=$(cat "${PULL_SECRET}")
    export CHANGE_SPOKE_CLUSTERIMAGESET=${CLUSTERIMAGESET}
    export CHANGE_SPOKE_API=192.168.7.243
    export CHANGE_SPOKE_INGRESS=192.168.7.242
    export CHANGE_SPOKE_CLUSTER_NET_PREFIX=23
    export CHANGE_SPOKE_CLUSTER_NET_CIDR=10.128.0.0/14
    export CHANGE_SPOKE_SVC_NET_CIDR=172.30.0.0/16
    export CHANGE_RSA_HUB_PUB_KEY=$(oc get cm -n kube-system cluster-config-v1 -o yaml | grep -A 1 sshKey | tail -1)

    # RSA
    generate_rsa_spoke ${cluster}
    export CHANGE_RSA_PUB_KEY=$(cat ${RSA_PUB_FILE})
    export CHANGE_RSA_PRV_KEY=$(cat ${RSA_KEY_FILE})

    # Set vars
    export CHANGE_SPOKE_NAME=${cluster}
    grab_api_ingress ${cluster}
    export CHANGE_BASEDOMAIN=${HUB_BASEDOMAIN}
    export IGN_OVERRIDE_API_HOSTS=$(echo -n "${CHANGE_SPOKE_API} ${SPOKE_API_NAME}" | base64)
    export IGN_CSR_APPROVER_SCRIPT=$(base64 csr_autoapprover.sh -w0)
    export JSON_STRING_CFG_OVERRIDE_INFRAENV='{"ignition": {"version": "3.1.0"}, "storage": {"files": [{"path": "/etc/hosts", "append": [{"source": "data:text/plain;base64,'${IGN_OVERRIDE_API_HOSTS}'"}]}]}}'
    export JSON_STRING_CFG_OVERRIDE_BMH='{"ignition":{"version":"3.2.0"},"systemd":{"units":[{"name":"csr-approver.service","enabled":true,"contents":"[Unit]\nDescription=CSR Approver\nAfter=network.target\n\n[Service]\nUser=root\nType=oneshot\nExecStart=/bin/bash -c /opt/bin/csr-approver.sh\n\n[Install]\nWantedBy=multi-user.target"}]},"storage":{"files":[{"path":"/opt/bin/csr-approver.sh","mode":492,"append":[{"source":"data:text/plain;base64,'${IGN_CSR_APPROVER_SCRIPT}'"}]}]}}'
    # Generate the spoke definition yaml
    cat <<EOF >${OUTPUTDIR}/${cluster}-cluster.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: $CHANGE_SPOKE_NAME
---
apiVersion: v1
kind: Secret
metadata:
  name: $CHANGE_SPOKE_PULL_SECRET_NAME
  namespace: $CHANGE_SPOKE_NAME
stringData:
  .dockerconfigjson: '$CHANGE_PULL_SECRET'
  type: kubernetes.io/dockerconfigjson
---
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: $CHANGE_SPOKE_NAME
  namespace: $CHANGE_SPOKE_NAME
spec:
  clusterDeploymentRef:
    name: $CHANGE_SPOKE_NAME
  imageSetRef:
    name: $CHANGE_SPOKE_CLUSTERIMAGESET
  fips: true
  apiVIP: "$CHANGE_SPOKE_API"
  ingressVIP: "$CHANGE_SPOKE_INGRESS"
  networking:
    clusterNetwork:
      - cidr: "$CHANGE_SPOKE_CLUSTER_NET_CIDR"
        hostPrefix: $CHANGE_SPOKE_CLUSTER_NET_PREFIX
    serviceNetwork:
      - "$CHANGE_SPOKE_SVC_NET_CIDR"
  provisionRequirements:
    controlPlaneAgents: 3
  sshPublicKey: '$CHANGE_RSA_PUB_KEY'
---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: $CHANGE_SPOKE_NAME
  namespace: $CHANGE_SPOKE_NAME
spec:
  baseDomain: $CHANGE_BASEDOMAIN
  clusterName: $CHANGE_SPOKE_NAME
  controlPlaneConfig:
    servingCertificates: {}
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: $CHANGE_SPOKE_NAME
    version: v1beta1
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          cluster-name: "$CHANGE_SPOKE_NAME"
  pullSecretRef:
    name: $CHANGE_SPOKE_PULL_SECRET_NAME
---
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $CHANGE_SPOKE_NAME
  namespace: $CHANGE_SPOKE_NAME
spec:
  clusterName: $CHANGE_SPOKE_NAME
  clusterNamespace: $CHANGE_SPOKE_NAME
  clusterLabels:
    name: $CHANGE_SPOKE_NAME
    cloud: Baremetal
  applicationManager:
    argocdCluster: false
    enabled: true
  certPolicyController:
    enabled: true
  iamPolicyController:
    enabled: true
  policyController:
    enabled: true
  searchCollector:
    enabled: true
---
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: $CHANGE_SPOKE_NAME
  namespace: $CHANGE_SPOKE_NAME
  labels:
    name: $CHANGE_SPOKE_NAME
    ztpfw: "true"
spec:
  hubAcceptsClient: true
  leaseDurationSeconds: 60
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
 name: '$CHANGE_SPOKE_NAME'
 namespace: '$CHANGE_SPOKE_NAME'
spec:
 clusterRef:
   name: '$CHANGE_SPOKE_NAME'
   namespace: '$CHANGE_SPOKE_NAME'
 pullSecretRef:
   name: '$CHANGE_SPOKE_PULL_SECRET_NAME'
 nmStateConfigLabelSelector:
   matchLabels:
     nmstate_config_cluster_name: $CHANGE_SPOKE_NAME
 ignitionConfigOverride: '${JSON_STRING_CFG_OVERRIDE_INFRAENV}'
 sshAuthorizedKey: '$CHANGE_RSA_PUB_KEY'
EOF

    # Generic vars for all masters
    export CHANGE_SPOKE_MASTER_PUB_INT_MASK=24
    export CHANGE_SPOKE_MASTER_PUB_INT_GW=192.168.7.1
    export CHANGE_SPOKE_MASTER_PUB_INT_ROUTE_DEST=192.168.7.0/24

    # Now process blocks for each master
    for master in $(echo $(seq 0 $(($(yq eval ".spokes[${spokenumber}].[]|keys" ${SPOKES_FILE} | grep master | wc -l) - 1)))); do
        # Master loop
        export CHANGE_SPOKE_MASTER_PUB_INT=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.nic_int_static" ${SPOKES_FILE})
        export CHANGE_SPOKE_MASTER_MGMT_INT=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})
        export CHANGE_SPOKE_MASTER_PUB_INT_IP=192.168.7.1${master}
        export CHANGE_SPOKE_MASTER_PUB_INT_MAC=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.mac_int_static" ${SPOKES_FILE})
        export CHANGE_SPOKE_MASTER_BMC_USERNAME=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.bmc_user" ${SPOKES_FILE} | base64)
        export CHANGE_SPOKE_MASTER_BMC_PASSWORD=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.bmc_pass" ${SPOKES_FILE} | base64)
        export CHANGE_SPOKE_MASTER_BMC_URL=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.bmc_url" ${SPOKES_FILE})
        export CHANGE_SPOKE_MASTER_MGMT_INT_MAC=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})
        export CHANGE_SPOKE_MASTER_ROOT_DISK=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.root_disk" ${SPOKES_FILE})

        # Now, write the template to disk
        OUTPUT="${OUTPUTDIR}/${cluster}-master-${master}.yaml"
        cat <<EOF >${OUTPUT}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
 name: ztpfw-${cluster}-master-${master}
 namespace: $CHANGE_SPOKE_NAME
 labels:
   nmstate_config_cluster_name: $CHANGE_SPOKE_NAME
spec:
 config:
   interfaces:
     - name: $CHANGE_SPOKE_MASTER_MGMT_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 10000
       ipv4:
         enabled: true
         dhcp: true
         auto-dns: true
         auto-gateway: true
         auto-routes: true
       mtu: 1500
     - name: $CHANGE_SPOKE_MASTER_PUB_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 1000
       ipv4:
         enabled: true
         address:
           - ip: $CHANGE_SPOKE_MASTER_PUB_INT_IP
             prefix-length: $CHANGE_SPOKE_MASTER_PUB_INT_MASK
       mtu: 1500
       mac-address: '$CHANGE_SPOKE_MASTER_PUB_INT_MAC'
EOF
        echo ">> Checking Ignored Interfaces"
        echo "Spoke: ${cluster}"
        echo "Master: ${master}"
        IGN_IFACES=$(yq eval ".spokes[${spokenumber}].${cluster}.master${master}.ignore_ifaces" ${SPOKES_FILE})
        if [[ ${IGN_IFACES} != "null" ]]; then
            yq eval -ojson ".spokes[${spokenumber}].${cluster}.master${master}.ignore_ifaces" ${SPOKES_FILE} | jq -c '.[]' | while read IFACE; do
                echo "Ignoring Interface: ${IFACE}"
                echo "     - name: ${IFACE}" >>${OUTPUT}

            done
        fi

        cat <<EOF >>${OUTPUT}
   routes:
     config:
       - destination: $CHANGE_SPOKE_MASTER_PUB_INT_ROUTE_DEST
         next-hop-address: $CHANGE_SPOKE_MASTER_PUB_INT_GW
         next-hop-interface: $CHANGE_SPOKE_MASTER_PUB_INT
EOF

        if [[ ${IGN_IFACES} != "null" ]]; then
            yq eval -ojson ".spokes[${spokenumber}].${cluster}.master${master}.ignore_ifaces" ${SPOKES_FILE} | jq -c '.[]' | while read IFACE; do
                echo "Ignoring route for: ${IFACE}"
                echo "       - next-hop-interface: ${IFACE}" >>${OUTPUT}
                echo "         state: absent" >>${OUTPUT}
            done
        fi
        cat <<EOF >>${OUTPUT}
 interfaces:
   - name: "$CHANGE_SPOKE_MASTER_MGMT_INT"
     macAddress: '$CHANGE_SPOKE_MASTER_MGMT_INT_MAC'
   - name: "$CHANGE_SPOKE_MASTER_PUB_INT"
     macAddress: '$CHANGE_SPOKE_MASTER_PUB_INT_MAC'
---
apiVersion: v1
kind: Secret
metadata:
 name: 'ztpfw-${cluster}-master-${master}-bmc-secret'
 namespace: '$CHANGE_SPOKE_NAME'
type: Opaque
data:
 username: '$CHANGE_SPOKE_MASTER_BMC_USERNAME'
 password: '$CHANGE_SPOKE_MASTER_BMC_PASSWORD'
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
 name: 'ztpfw-${cluster}-master-${master}'
 namespace: '$CHANGE_SPOKE_NAME'
 labels:
   infraenvs.agent-install.openshift.io: '$CHANGE_SPOKE_NAME'
 annotations:
   inspect.metal3.io: disabled
   bmac.agent-install.openshift.io/hostname: 'ztpfw-${cluster}-master-${master}'
   bmac.agent-install.openshift.io/ignition-config-overrides: '${JSON_STRING_CFG_OVERRIDE_BMH}'
spec:
 online: false
 bootMACAddress: '$CHANGE_SPOKE_MASTER_MGMT_INT_MAC'
 rootDeviceHints:
   deviceName: '$CHANGE_SPOKE_MASTER_ROOT_DISK'
 bmc:
   disableCertificateVerification: true
   address: '$CHANGE_SPOKE_MASTER_BMC_URL'
   credentialsName: 'ztpfw-${cluster}-master-${master}-bmc-secret'
EOF

    done
}

## MAIN
# Load common vars
source ${WORKDIR}/shared-utils/common.sh

# Cleanup
echo ">>>> Cleaning up the previous BUILD folder"
find ${OUTPUTDIR} -type f | grep -vE 'spokes.yaml|pull-secret.json|kubeconfig-hub' | xargs rm -fv

# Check first item only
RESULT=$(yq eval ".spokes[0]" ${SPOKES_FILE})

if [ "${RESULT}" == "null" ]; then
    echo "Couldn't evaluate name of first spoke in YAML at $SPOKES_FILE, please check and retry"
    exit 1
fi

if [[ -z ${ALLSPOKES} ]]; then
    ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

index=0

for spoke in ${ALLSPOKES}; do
    create_kustomization ${spoke} ${index}
    create_spoke_definitions ${spoke} ${index}
    index=$((index + 1))
done
