#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

usage() { echo "Usage: $0 <pull-secret-file> <ocp-version(4.10.6)> <acm_version(2.4)> <odf_version(4.8)> <hub_architecture(installer|sno)>" 1>&2; exit 1; }

if [ $# -lt 4 ]; then
    usage
fi

export pull_secret=${1}
export ocp_version=${2}
export acm_version=${3}
export odf_version=${4}

if [ -z "${pull_secret}" ] || [ -z "${ocp_version}" ] || [ -z "${acm_version}" ] || [ -z "${odf_version}" ]; then
    usage
fi

if [[ "$ocp_version" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
    echo "ocp_version is valid"
else
    echo $ocp_version
    echo "ocp_version is not valid"
    usage
fi


# variables
# #########
export DEPLOY_OCP_DIR="./"
export OC_RELEASE="quay.io/openshift-release-dev/ocp-release:$ocp_version-x86_64"
export OC_CLUSTER_NAME="test-ci"
export OC_DEPLOY_METAL="yes"
export OC_NET_CLASS="ipv4"
export OC_TYPE_ENV="connected"
export VERSION="ci"
export CLUSTERS=1
export OC_PULL_SECRET="'$(cat $pull_secret)'"
export OC_OCP_VERSION="${ocp_version}"
export OC_ACM_VERSION="${acm_version}"
export OC_ODF_VERSION="${odf_version}"
export HUB_ARCHITECTURE="${5:-compact}"



echo ">>>> Set the Pull Secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"
echo $OC_PULL_SECRET | tr -d [:space:] | sed -e 's/^.//' -e 's/.$//' >./openshift_pull.json

echo ">>>> kcli create plan"
echo ">>>>>>>>>>>>>>>>>>>>>"

if [ "${OC_DEPLOY_METAL}" = "yes" ]; then
    if [ "${OC_NET_CLASS}" = "ipv4" ]; then
        if [ "${OC_TYPE_ENV}" = "connected" ]; then
          if [ "${HUB_ARCHITECTURE}" = "sno" ]; then
            echo "Metal3 + Ipv4 + connected"
            t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
            kcli create plan -k -f create-vm-sno.yml -P clusters="${CLUSTERS}" "${OC_CLUSTER_NAME}"
          else
            echo "Metal3 + Ipv4 + connected"
            t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
            kcli create plan -k -f create-vm.yml -P clusters="${CLUSTERS}" "${OC_CLUSTER_NAME}"
          fi
        else
            echo "Metal3 + ipv4 + disconnected"
            echo "Not implemented yet"
            #t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
        fi
    else
        echo "Metal3 + ipv6 + disconnected"
        echo "Not implemented yet"
        #t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
    fi
else
    echo "Without Metal3 + ipv4 + connected"
    echo "Not implemented yet"
fi

# Spokes.yaml file generation

#Empty file before we start

>spokes.yaml
CHANGE_IP=192.168.150.1  # hypervisor ip for this network
if [ "${HUB_ARCHITECTURE}" = "compact" ]; then
  MASTERS=3
else
  MASTERS=1
fi
# Default configuration
cat <<EOF >>spokes.yaml
config:
  OC_OCP_VERSION: '${OC_OCP_VERSION}'
  OC_ACM_VERSION: '${OC_ACM_VERSION}'
  OC_ODF_VERSION: '${OC_ODF_VERSION}'

EOF

# Create header for spokes.yaml
cat <<EOF >>spokes.yaml
spokes:
EOF
# Create header for spokes.yaml

for spoke in $(seq 0 $((CLUSTERS - 1))); do
    cat <<EOF >>spokes.yaml
  - spoke${spoke}-cluster:
      contrib:
        gpu-operator:
          version: "v1.10.1"
EOF
    for master in $(seq 0 $((MASTERS - 1))); do
        # Stanza generation for each master
        MASTERUID=$(kcli info vm spoke${spoke}-cluster-m${master} -f id -v)
        cat <<EOF >>spokes.yaml
      master${master}:
        nic_ext_dhcp: enp1s0
        nic_int_static: enp2s0
        mac_ext_dhcp: "ee:ee:ee:ee:${master}${spoke}:${master}e"
        mac_int_static: "aa:aa:aa:aa:${master}${spoke}:${master}a"
        bmc_url: "redfish-virtualmedia+http://${CHANGE_IP}:8000/redfish/v1/Systems/${MASTERUID}"
        bmc_user: "amorgant"
        bmc_pass: "alknopfler"
        root_disk: /dev/vda
        storage_disk:
          - /dev/vdb
          - /dev/vdc
          - /dev/vdd
          - /dev/vde
EOF
    done

  if [ "${HUB_ARCHITECTURE}" = "compact" ]; then
    # Add the single worker
    worker=0
    WORKERUID=$(kcli info vm spoke${spoke}-cluster-w${worker} -f id -v)

    cat <<EOF >>spokes.yaml
      worker${worker}:
        nic_ext_dhcp: enp1s0
        nic_int_static: enp2s0
        mac_ext_dhcp: "ee:ee:ee:${worker}${spoke}:${worker}${spoke}:${worker}e"
        mac_int_static: "aa:aa:aa:${worker}${spoke}:${worker}${spoke}:${worker}a"
        bmc_url: "redfish-virtualmedia+http://${CHANGE_IP}:8000/redfish/v1/Systems/${WORKERUID}"
        bmc_user: "amorgant"
        bmc_pass: "alknopfler"
        root_disk: /dev/vda
        storage_disk:
          - /dev/vdb
          - /dev/vdc
          - /dev/vdd
          - /dev/vde
EOF
  fi

done

echo ">>>> EOF"
echo ">>>>>>>>"
