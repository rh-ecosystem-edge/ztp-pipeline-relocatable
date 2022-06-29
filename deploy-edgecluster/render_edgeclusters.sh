#!/usr/bin/env bash
# Description: Renders clusters YAML into different files for each edgecluster cluster

set -o pipefail
set -o nounset
set -m

create_kustomization() {
    # Loop for edgeclusters
    # Prepare loop for edgeclusters
    local cluster=${1}
    local edgeclusternumber=${2}

    # Pregenerate kustomization.yaml and edgecluster cluster config
    OUTPUT="${OUTPUTDIR}/kustomization.yaml"

    # Write header
    echo "resources:" >${OUTPUT}

    echo ">> Detecting number of masters"
    export NUM_M=$(yq e ".edgeclusters[${edgeclusternumber}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l | xargs)
    echo ">> Masters: ${NUM_M}"
    export NUM_M=$((NUM_M - 1))

    echo ">> Rendering Kustomize for: ${cluster}"
    for node in $(seq 0 ${NUM_M}); do
        echo "  - ${cluster}-master-${node}.yaml" >>${OUTPUT}
    done
    echo "  - ${cluster}-cluster.yaml" >>${OUTPUT}
}

create_edgecluster_definitions() {
    # Reset loop for edgecluster general definition
    local cluster=${1}
    local edgeclusternumber=${2}
    echo ">> Detecting number of masters"
    export NUM_M=$(yq e ".edgeclusters[${edgeclusternumber}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l | xargs)

    # Generic vars for all edgeclusters
    export CHANGE_MACHINE_CIDR=192.168.7.0/24
    export CHANGE_EDGE_PULL_SECRET_NAME=pull-secret-edgecluster-cluster
    export CHANGE_PULL_SECRET=$(cat "${PULL_SECRET}")
    export CHANGE_EDGE_CLUSTERIMAGESET=${CLUSTERIMAGESET}
    export CHANGE_EDGE_API=192.168.7.243
    export CHANGE_EDGE_INGRESS=192.168.7.242
    export CHANGE_EDGE_CLUSTER_NET_PREFIX=23
    export CHANGE_EDGE_CLUSTER_NET_CIDR=10.128.0.0/14
    export CHANGE_EDGE_SVC_NET_CIDR=172.30.0.0/16
    export CHANGE_RSA_HUB_PUB_KEY=$(oc get cm -n kube-system cluster-config-v1 -o yaml | grep -A 1 sshKey | tail -1)

    # RSA
    generate_rsa_edgecluster ${cluster}
    export CHANGE_RSA_PUB_KEY=$(cat ${RSA_PUB_FILE})
    export CHANGE_RSA_PRV_KEY=$(cat ${RSA_KEY_FILE})

    # Set vars
    export CHANGE_EDGE_NAME=${cluster}
    grab_api_ingress ${cluster}
    export CHANGE_EDGE_MASTER_PUB_INT_M0=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master0.nic_int_static" ${EDGECLUSTERS_FILE})
    export CHANGE_EDGE_MASTER_MGMT_INT_M0=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master0.nic_ext_dhcp" ${EDGECLUSTERS_FILE})
    export DATA_PUB_INT_M0=$(echo "${CHANGE_EDGE_MASTER_PUB_INT_M0}" | base64 -w0)
    export CHANGE_BASEDOMAIN=${HUB_BASEDOMAIN}
    export IGN_OVERRIDE_API_HOSTS=$(echo -n "${CHANGE_EDGE_API} ${EDGE_API_NAME}" | base64 -w0)
    export IGN_CSR_APPROVER_SCRIPT=$(base64 csr_autoapprover.sh -w0)
    export IGN_CHANGE_DEF_ROUTE_SCRIPT=$(base64 change_def_route.sh -w0)
    export JSON_STRING_CFG_OVERRIDE_INFRAENV='{"ignition":{"version":"3.1.0"},"storage":{"files":[{"path":"/etc/hosts","append":[{"source":"data:text/plain;base64,'${IGN_OVERRIDE_API_HOSTS}'"}]}]}}'
    export JSON_STRING_CFG_OVERRIDE_BMH='{"ignition":{"version":"3.2.0"},"systemd":{"units":[{"name":"csr-approver.service","enabled":true,"contents":"[Unit]\nDescription=CSR Approver\nAfter=network.target\n\n[Service]\nUser=root\nType=oneshot\nExecStart=/bin/bash -c /opt/bin/csr-approver.sh\n\n[Install]\nWantedBy=multi-user.target"},{"name":"change-def-route.service","enabled":true,"contents":"[Unit]\nDescription=Change Default Route\nAfter=network.target\n\n[Service]\nUser=root\nType=simple\nExecStart=/bin/bash -c /opt/bin/change_def_route.sh '${CHANGE_EDGE_MASTER_MGMT_INT_M0'}\n\n[Install]\nWantedBy=multi-user.target"},{"name":"crio-wipe.service","mask":true}]},"storage":{"files":[{"path":"/opt/bin/csr-approver.sh","mode":492,"append":[{"source":"data:text/plain;base64,'${IGN_CSR_APPROVER_SCRIPT}'"}]},{"path":"/opt/bin/change_def_route.sh","mode":492,"append":[{"source":"data:text/plain;base64,'${IGN_CHANGE_DEF_ROUTE_SCRIPT}'"}]},{"path":"/var/lib/ovnk/iface_default_hint","mode":492,"override":true,"contents":{"source":"data:text/plain;base64,'${DATA_PUB_INT_M0}'"}}]}}'

    # Generate the edgecluster definition yaml
    cat <<EOF >${OUTPUTDIR}/${cluster}-cluster.yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: $CHANGE_EDGE_NAME
---
apiVersion: v1
kind: Secret
metadata:
  name: $CHANGE_EDGE_PULL_SECRET_NAME
  namespace: $CHANGE_EDGE_NAME
stringData:
  .dockerconfigjson: '$CHANGE_PULL_SECRET'
  type: kubernetes.io/dockerconfigjson
EOF
    if [ "${NUM_M}" -eq "1" ]; then
        cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: $CHANGE_EDGE_NAME-manifests-override
  namespace: $CHANGE_EDGE_NAME
  annotations:
    manifests-directory: manifests
data:
  node-ip-config.yml: |
    apiVersion: machineconfiguration.openshift.io/v1
    kind: MachineConfig
    metadata:
      labels:
        machineconfiguration.openshift.io/role: master
      name: 10-masters-node-ip-hint
    spec:
      config:
        ignition:
          config: {}
          security:
            tls: {}
          timeouts: {}
          version: 2.2.0
        networkd: {}
        passwd: {}
        storage:
          files:
          - contents:
              source: data:text/plain;charset=utf-8;base64,S1VCRUxFVF9OT0RFSVBfSElOVD0xOTIuMTY4LjcuMA==
              verification: {}
            filesystem: root
            mode: 420
            path: /etc/default/nodeip-configuration
EOF
    fi
    cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
---
apiVersion: extensions.hive.openshift.io/v1beta1
kind: AgentClusterInstall
metadata:
  name: $CHANGE_EDGE_NAME
  namespace: $CHANGE_EDGE_NAME
spec:
  clusterDeploymentRef:
    name: $CHANGE_EDGE_NAME
EOF
    if [ "${NUM_M}" -eq "1" ]; then
        cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
  manifestsConfigMapRef:
    name: $CHANGE_EDGE_NAME-manifests-override
EOF
    fi
    cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
  imageSetRef:
    name: $CHANGE_EDGE_CLUSTERIMAGESET
  fips: true
EOF
    if [ "${NUM_M}" -eq "3" ]; then
        cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
  apiVIP: "$CHANGE_EDGE_API"
  ingressVIP: "$CHANGE_EDGE_INGRESS"
  networking:
    networkType: OVNKubernetes
    clusterNetwork:
      - cidr: "$CHANGE_EDGE_CLUSTER_NET_CIDR"
        hostPrefix: $CHANGE_EDGE_CLUSTER_NET_PREFIX
    serviceNetwork:
      - "$CHANGE_EDGE_SVC_NET_CIDR"
  provisionRequirements:
    controlPlaneAgents: 3
EOF
    else # SNO
        cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
  networking:
    networkType: OVNKubernetes
    clusterNetwork:
      - cidr: "$CHANGE_EDGE_CLUSTER_NET_CIDR"
        hostPrefix: $CHANGE_EDGE_CLUSTER_NET_PREFIX
    serviceNetwork:
      - "$CHANGE_EDGE_SVC_NET_CIDR"
    machineNetwork:
      - cidr: "$CHANGE_MACHINE_CIDR"
  provisionRequirements:
    controlPlaneAgents: 1
EOF
    fi
    cat <<EOF >>${OUTPUTDIR}/${cluster}-cluster.yaml
  sshPublicKey: '$CHANGE_RSA_PUB_KEY'
---
apiVersion: hive.openshift.io/v1
kind: ClusterDeployment
metadata:
  name: $CHANGE_EDGE_NAME
  namespace: $CHANGE_EDGE_NAME
spec:
  baseDomain: $CHANGE_BASEDOMAIN
  clusterName: $CHANGE_EDGE_NAME
  controlPlaneConfig:
    servingCertificates: {}
  clusterInstallRef:
    group: extensions.hive.openshift.io
    kind: AgentClusterInstall
    name: $CHANGE_EDGE_NAME
    version: v1beta1
  platform:
    agentBareMetal:
      agentSelector:
        matchLabels:
          cluster-name: "$CHANGE_EDGE_NAME"
  pullSecretRef:
    name: $CHANGE_EDGE_PULL_SECRET_NAME
---
apiVersion: agent.open-cluster-management.io/v1
kind: KlusterletAddonConfig
metadata:
  name: $CHANGE_EDGE_NAME
  namespace: $CHANGE_EDGE_NAME
spec:
  clusterName: $CHANGE_EDGE_NAME
  clusterNamespace: $CHANGE_EDGE_NAME
  clusterLabels:
    name: $CHANGE_EDGE_NAME
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
  name: $CHANGE_EDGE_NAME
  namespace: $CHANGE_EDGE_NAME
  labels:
    name: $CHANGE_EDGE_NAME
    ztpfw: "true"
spec:
  hubAcceptsClient: true
  leaseDurationSeconds: 60
---
apiVersion: agent-install.openshift.io/v1beta1
kind: InfraEnv
metadata:
 name: '$CHANGE_EDGE_NAME'
 namespace: '$CHANGE_EDGE_NAME'
spec:
 clusterRef:
   name: '$CHANGE_EDGE_NAME'
   namespace: '$CHANGE_EDGE_NAME'
 pullSecretRef:
   name: '$CHANGE_EDGE_PULL_SECRET_NAME'
 nmStateConfigLabelSelector:
   matchLabels:
     nmstate_config_cluster_name: $CHANGE_EDGE_NAME
 ignitionConfigOverride: '${JSON_STRING_CFG_OVERRIDE_INFRAENV}'
 sshAuthorizedKey: '$CHANGE_RSA_PUB_KEY'
EOF

    # Generic vars for all masters
    export CHANGE_EDGE_MASTER_PUB_INT_MASK=24
    export CHANGE_EDGE_MASTER_PUB_INT_GW=192.168.7.1
    export CHANGE_EDGE_MASTER_PUB_INT_ROUTE_DEST=192.168.7.0/24

    # Now process blocks for each master
    for master in $(echo $(seq 0 $(($(yq eval ".edgeclusters[${edgeclusternumber}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l) - 1)))); do
        # Master loop
        export CHANGE_EDGE_MASTER_PUB_INT=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.nic_int_static" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_MASTER_MGMT_INT=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.nic_ext_dhcp" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_MASTER_PUB_INT_IP=192.168.7.1${master}
        export CHANGE_EDGE_MASTER_PUB_INT_MAC=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.mac_int_static" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_MASTER_BMC_USERNAME=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.bmc_user" ${EDGECLUSTERS_FILE} | base64)
        export CHANGE_EDGE_MASTER_BMC_PASSWORD=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.bmc_pass" ${EDGECLUSTERS_FILE} | base64)
        export CHANGE_EDGE_MASTER_BMC_URL=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.bmc_url" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_MASTER_MGMT_INT_MAC=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.mac_ext_dhcp" ${EDGECLUSTERS_FILE})
        export CHANGE_EDGE_MASTER_ROOT_DISK=$(yq eval ".edgeclusters[${edgeclusternumber}].${cluster}.master${master}.root_disk" ${EDGECLUSTERS_FILE})

        # Now, write the template to disk
        OUTPUT="${OUTPUTDIR}/${cluster}-master-${master}.yaml"
        cat <<EOF >${OUTPUT}
---
apiVersion: agent-install.openshift.io/v1beta1
kind: NMStateConfig
metadata:
 name: ztpfw-${cluster}-master-${master}
 namespace: $CHANGE_EDGE_NAME
 labels:
   nmstate_config_cluster_name: $CHANGE_EDGE_NAME
spec:
 config:
   interfaces:
     - name: $CHANGE_EDGE_MASTER_MGMT_INT
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
       mac-address: '$CHANGE_EDGE_MASTER_MGMT_INT_MAC'
EOF
        echo ">> Checking Number of Interfaces"
        echo "Edge-cluster: ${cluster}"
        echo "Master: ${master}"
        if [[ ${CHANGE_EDGE_MASTER_PUB_INT_MAC} == "null" ]]; then
            cat <<EOF >>${OUTPUT}
     - name: $CHANGE_EDGE_MASTER_MGMT_INT.102
       type: vlan
       state: up
       vlan:
         base-iface: $CHANGE_EDGE_MASTER_MGMT_INT
         id: 102
       ipv4:
         enabled: true
         address:
           - ip: $CHANGE_EDGE_MASTER_PUB_INT_IP
             prefix-length: $CHANGE_EDGE_MASTER_PUB_INT_MASK
       mtu: 1500
EOF
        else
            cat <<EOF >>${OUTPUT}
     - name: $CHANGE_EDGE_MASTER_PUB_INT
       type: ethernet
       state: up
       ethernet:
         auto-negotiation: true
         duplex: full
         speed: 1000
       ipv4:
         enabled: true
         address:
           - ip: $CHANGE_EDGE_MASTER_PUB_INT_IP
             prefix-length: $CHANGE_EDGE_MASTER_PUB_INT_MASK
       mtu: 1500
EOF
        fi
        echo ">> Checking Ignored Interfaces"
        echo "Edge-cluster: ${cluster}"
        echo "Master: ${master}"
        IGN_IFACES=$(yq eval ".edgeclusters[${edgeclusternumber}].[].master${master}.ignore_ifaces" ${EDGECLUSTERS_FILE})
        if [[ ${IGN_IFACES} != "null" ]]; then
            for IFACE in $(echo ${IGN_IFACES}); do

                echo "Ignoring Interface: ${IFACE}"
                echo "     - name: ${IFACE}" >>${OUTPUT}

            done
        fi

        cat <<EOF >>${OUTPUT}
   routes:
     config:
       - destination: $CHANGE_EDGE_MASTER_PUB_INT_ROUTE_DEST
         next-hop-address: $CHANGE_EDGE_MASTER_PUB_INT_GW
EOF
        if [[ ${CHANGE_EDGE_MASTER_PUB_INT_MAC} == "null" ]]; then
            cat <<EOF >>${OUTPUT}
         next-hop-interface: $CHANGE_EDGE_MASTER_MGMT_INT.102
EOF
        else
            cat <<EOF >>${OUTPUT}
         next-hop-interface: $CHANGE_EDGE_MASTER_PUB_INT
EOF
        fi
        export NUM_M=$(yq e ".edgeclusters[${edgeclusternumber}].[]|keys" ${EDGECLUSTERS_FILE} | grep master | wc -l | xargs)
        echo "NUM_M: $NUM_M"
        if [[ "${NUM_M}" -eq "1" || "${NUM_M}" -eq "3" ]]; then
            cat <<EOF >>${OUTPUT}
       - destination: 0.0.0.0/0
         next-hop-address: $CHANGE_EDGE_MASTER_PUB_INT_GW
         metric: 101
         table-id: 254
EOF
          if [[ ${CHANGE_EDGE_MASTER_PUB_INT_MAC} == "null" ]]; then
            cat <<EOF >>${OUTPUT}
         next-hop-interface: $CHANGE_EDGE_MASTER_MGMT_INT.102
EOF
          else
            cat <<EOF >>${OUTPUT}
         next-hop-interface: $CHANGE_EDGE_MASTER_PUB_INT
EOF
          fi
        fi
        if [[ ${IGN_IFACES} != "null" ]]; then
            for IFACE in $(echo ${IGN_IFACES}); do
                echo "Ignoring route for: ${IFACE}"
                echo "       - next-hop-interface: ${IFACE}" >>${OUTPUT}
                echo "         state: absent" >>${OUTPUT}
            done
        fi
        cat <<EOF >>${OUTPUT}
 interfaces:
   - name: "$CHANGE_EDGE_MASTER_MGMT_INT"
     macAddress: '$CHANGE_EDGE_MASTER_MGMT_INT_MAC'
EOF
        if [[ ${CHANGE_EDGE_MASTER_PUB_INT_MAC} != "null" ]]; then
            cat <<EOF >>${OUTPUT}
   - name: "$CHANGE_EDGE_MASTER_PUB_INT"
     macAddress: '$CHANGE_EDGE_MASTER_PUB_INT_MAC'
EOF
        fi
        cat <<EOF >>${OUTPUT}
---
apiVersion: v1
kind: Secret
metadata:
 name: 'ztpfw-${cluster}-master-${master}-bmc-secret'
 namespace: '$CHANGE_EDGE_NAME'
type: Opaque
data:
 username: '$CHANGE_EDGE_MASTER_BMC_USERNAME'
 password: '$CHANGE_EDGE_MASTER_BMC_PASSWORD'
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
 name: 'ztpfw-${cluster}-master-${master}'
 namespace: '$CHANGE_EDGE_NAME'
 labels:
   infraenvs.agent-install.openshift.io: '$CHANGE_EDGE_NAME'
 annotations:
   inspect.metal3.io: disabled
   bmac.agent-install.openshift.io/hostname: 'ztpfw-${cluster}-master-${master}'
   bmac.agent-install.openshift.io/ignition-config-overrides: '${JSON_STRING_CFG_OVERRIDE_BMH}'
spec:
 online: false
 bootMACAddress: '$CHANGE_EDGE_MASTER_MGMT_INT_MAC'
 rootDeviceHints:
   deviceName: '$CHANGE_EDGE_MASTER_ROOT_DISK'
 bmc:
   disableCertificateVerification: true
   address: '$CHANGE_EDGE_MASTER_BMC_URL'
   credentialsName: 'ztpfw-${cluster}-master-${master}-bmc-secret'
EOF

    done
}

## MAIN
# Load common vars
source ${WORKDIR}/shared-utils/common.sh

# Cleanup
echo ">>>> Cleaning up the previous BUILD folder"
find ${OUTPUTDIR} -type f | grep -vE 'edgeclusters.yaml|pull-secret.json|kubeconfig-hub' | xargs rm -fv

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

for edgecluster in ${ALLEDGECLUSTERS}; do
    create_kustomization ${edgecluster} ${index}
    create_edgecluster_definitions ${edgecluster} ${index}
    index=$((index + 1))
done
