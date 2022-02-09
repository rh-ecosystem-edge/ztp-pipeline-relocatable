#!/usr/bin/env bash
# Description: Renders clusters YAML into different files for each spoke cluster

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

create_kustomization() {
    # Loop for spokes
    # Prepare loop for spokes
    i=0

    # Check first item
    RESULT=$(yq eval ".spokes[${i}]" ${SPOKES_FILE})
    # Pregenerate kustomization.yaml and spoke cluster config
    OUTPUT="${OUTPUTDIR}/kustomization.yaml"

    # Write header
    echo "resources:" >${OUTPUT}

    while [ "${RESULT}" != "null" ]; do
        # Generate the 4 files for each spoke
        cat <<EOF >>${OUTPUT}
  - spoke-${i}-cluster.yaml
  - spoke-${i}-master-0.yaml
  - spoke-${i}-master-1.yaml
  - spoke-${i}-master-2.yaml
EOF

        # Prepare for next loop
        i=$((i + 1))
        RESULT=$(yq eval ".spokes[${i}]" ${SPOKES_FILE})
    done
}

create_spoke_definitions() {
    # Reset loop for spoke general definition
    i=0
    RESULT=$(yq eval ".spokes[${i}]" ${SPOKES_FILE})

    # Generic vars for all spokes
    export CHANGE_SPOKE_PULL_SECRET_NAME=pull-secret-spoke-cluster
    export CHANGE_PULL_SECRET=$(cat "${PULL_SECRET}")
    export CHANGE_SPOKE_CLUSTERIMAGESET=$(yq eval ".config.clusterimageset" ${SPOKES_FILE})
    export CHANGE_SPOKE_API=192.168.7.243
    export CHANGE_SPOKE_INGRESS=192.168.7.242
    export CHANGE_SPOKE_CLUSTER_NET_PREFIX=23
    export CHANGE_SPOKE_CLUSTER_NET_CIDR=10.128.0.0/14
    export CHANGE_SPOKE_SVC_NET_CIDR=172.30.0.0/16
    export CHANGE_RSA_PUB_KEY=$(oc get cm -n kube-system cluster-config-v1 -o yaml | grep -A 1 sshKey | tail -1)

    while [ "${RESULT}" != "null" ]; do
        SPOKE_NAME=$(echo $RESULT | cut -d ":" -f 1)
        generate_rsa_spoke ${SPOKE_NAME}
        # Set vars
        export CHANGE_SPOKE_NAME=${SPOKE_NAME} # from input spoke-file
        grab_api_ingress ${SPOKE_NAME}
        export CHANGE_BASEDOMAIN=${HUB_BASEDOMAIN}
        export IGN_OVERRIDE_API_HOSTS=$(echo -n "${CHANGE_SPOKE_API} ${SPOKE_API_NAME}" | base64)
        export JSON_STRING_CFG_OVERRIDE='{"ignition": {"version": "3.1.0"}, "storage": {"files": [{"path": "/etc/hosts", "append": [{"source": "data:text/plain;base64,'${IGN_OVERRIDE_API_HOSTS}'"}]}]}}'

        # Generate the spoke definition yaml
        cat <<EOF >${OUTPUTDIR}/spoke-${i}-cluster.yaml
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
    kubeframe: "true"
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
 ignitionConfigOverride: '${JSON_STRING_CFG_OVERRIDE}'
 sshAuthorizedKey: '$CHANGE_RSA_PUB_KEY'
EOF

        # Generic vars for all masters
        export CHANGE_SPOKE_MASTER_PUB_INT_MASK=24
        export CHANGE_SPOKE_MASTER_PUB_INT_GW=192.168.7.1
        export CHANGE_SPOKE_MASTER_PUB_INT_ROUTE_DEST=192.168.7.0/24

        # Now process blocks for each master
        for master in 0 1 2; do

            # Master loop
            export CHANGE_SPOKE_MASTER_PUB_INT=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.nic_int_static" ${SPOKES_FILE})
            export CHANGE_SPOKE_MASTER_MGMT_INT=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.nic_ext_dhcp" ${SPOKES_FILE})

            export CHANGE_SPOKE_MASTER_PUB_INT_IP=192.168.7.1${master}

            export CHANGE_SPOKE_MASTER_PUB_INT_MAC=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.mac_int_static" ${SPOKES_FILE})
            export CHANGE_SPOKE_MASTER_BMC_USERNAME=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.bmc_user" ${SPOKES_FILE} | base64)
            export CHANGE_SPOKE_MASTER_BMC_PASSWORD=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.bmc_pass" ${SPOKES_FILE} | base64)
            export CHANGE_SPOKE_MASTER_BMC_URL=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.bmc_url" ${SPOKES_FILE})

            export CHANGE_SPOKE_MASTER_MGMT_INT_MAC=$(yq eval ".spokes[${i}].${SPOKE_NAME}.master${master}.mac_ext_dhcp" ${SPOKES_FILE})

            # Now, write the template to disk
            OUTPUT="${OUTPUTDIR}/spoke-${i}-master-${master}.yaml"

            cat <<EOF >${OUTPUT}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
 name: kubeframe-spoke-${i}-master-${master}
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
   routes:
     config:
       - destination: $CHANGE_SPOKE_MASTER_PUB_INT_ROUTE_DEST
         next-hop-address: $CHANGE_SPOKE_MASTER_PUB_INT_GW
         next-hop-interface: $CHANGE_SPOKE_MASTER_PUB_INT
 interfaces:
   - name: "$CHANGE_SPOKE_MASTER_MGMT_INT"
     macAddress: '$CHANGE_SPOKE_MASTER_MGMT_INT_MAC'
   - name: "$CHANGE_SPOKE_MASTER_PUB_INT"
     macAddress: '$CHANGE_SPOKE_MASTER_PUB_INT_MAC'
---
apiVersion: v1
kind: Secret
metadata:
 name: 'kubeframe-spoke-${i}-master-${master}-bmc-secret'
 namespace: '$CHANGE_SPOKE_NAME'
type: Opaque
data:
 username: '$CHANGE_SPOKE_MASTER_BMC_USERNAME'
 password: '$CHANGE_SPOKE_MASTER_BMC_PASSWORD'
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
 name: 'kubeframe-spoke-${i}-master-${master}'
 namespace: '$CHANGE_SPOKE_NAME'
 labels:
   infraenvs.agent-install.openshift.io: '$CHANGE_SPOKE_NAME'
 annotations:
   inspect.metal3.io: disabled
   bmac.agent-install.openshift.io/hostname: 'kubeframe-spoke-${i}-master-${master}'
spec:
 online: false
 bootMACAddress: '$CHANGE_SPOKE_MASTER_MGMT_INT_MAC'
 rootDeviceHints:
   deviceName: /dev/sda
 bmc:
   disableCertificateVerification: true
   address: '$CHANGE_SPOKE_MASTER_BMC_URL'
   credentialsName: 'kubeframe-spoke-${i}-master-${master}-bmc-secret'

EOF

        done

        # Prepare for next loop
        i=$((i + 1))
        RESULT=$(yq eval ".spokes[${i}]" ${SPOKES_FILE})
    done
}

# Main code

create_kustomization
create_spoke_definitions
