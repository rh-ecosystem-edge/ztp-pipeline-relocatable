#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

usage() { echo "Usage: $0 [-pull_secret <file>] [-ocp_version <4.10.6>] [-acm_version <2.4>] [-ocs_version <4.8>]" 1>&2; exit 1; }

while getopts ":pull_secret:ocp_version:ocs_version:" o; do
    case "${o}" in
        pull_secret)
            export pull_secret=${OPTARG}
            ;;
        ocp_version)
            export ocp_version=${OPTARG}
            [[ "$ocp_version" =~ [0-9].[0-9].[0-9] ]] || usage
            ;;
        acm_version)
            export acm_version=${OPTARG}
            [[ "$acm_version" =~ [0-9].[0-9] ]] || usage
            ;;
        ocs_version)
            export ocs_version=${OPTARG}
            [[ "$ocs_version" =~ [0-9].[0-9] ]] || usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${pull_secret}" ] || [ -z "${ocp_version}" || [ -z "${acm_version}" || [ -z "${ocs_version}" ]; then
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
export CLUSTERS=0
export OC_PULL_SECRET="'$(cat $pull_secret)'"


echo ">>>> Set the Pull Secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"
echo $OC_PULL_SECRET | tr -d [:space:] | sed -e 's/^.//' -e 's/.$//' >./openshift_pull.json

echo ">>>> kcli create plan"
echo ">>>>>>>>>>>>>>>>>>>>>"

if [ "${OC_DEPLOY_METAL}" = "yes" ]; then
    if [ "${OC_NET_CLASS}" = "ipv4" ]; then
        if [ "${OC_TYPE_ENV}" = "connected" ]; then
            echo "Metal3 + Ipv4 + connected"
            t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
            kcli create plan -k -f create-vm.yml -P clusters="${CLUSTERS}" "${OC_CLUSTER_NAME}"

        else
            echo "Metal3 + ipv4 + disconnected"
            t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
            
        fi
    else
        echo "Metal3 + ipv6 + disconnected"
        t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')

    fi
else
    echo "Without Metal3 + ipv4 + connected"
fi

# Spokes.yaml file generation

#Empty file before we start

>spokes.yaml

CHANGE_IP=$(kcli info vm test-ci-installer | grep ip | awk '{print $2}')
# Default configuration
echo "config: " >> spokes.yaml
echo "  OC_OCP_VERSION: '"${OC_OCP_VERSION}"'" >> spokes.yaml
echo "  OC_ACM_VERSION: '"${OC_ACM_VERSION}"'" >> spokes.yaml
echo "  OC_OCS_VERSION: '"${OC_OCS_VERSION}"'" >> spokes.yaml
echo "spokes: " >> spokes.yaml

# Create header for spokes.yaml

for spoke in $(seq 0 $((CLUSTERS - 1))); do
    echo "  - spoke${spoke}-cluster:" >>spokes.yaml
    for master in 0 1 2; do
        # Stanza generation for each master
        MASTERUID=$(kcli info vm spoke${spoke}-cluster-m${master} -f id -v)
        echo "      master${master}: " >> spokes.yaml
        echo "        nic_ext_dhcp: enp1s0" >> spokes.yaml
        echo "        nic_int_static: enp2s0" >> spokes.yaml
        echo "        mac_ext_dhcp: \"ee:ee:ee:ee:${master}${spoke}:${master}e\"" >> spokes.yaml
        echo "        mac_int_static: \"aa:aa:aa:aa:${master}${spoke}:${master}a\"" >> spokes.yaml
        echo "        bmc_url: \"redfish-virtualmedia+http://${CHANGE_IP}:8000/redfish/v1/Systems/${MASTERUID}\"" >> spokes.yaml
        echo "        bmc_user: \"amorgant\"" >> spokes.yaml
        echo "        bmc_pass: \"alknopfler\"" >> spokes.yaml
        echo "        storage_disk:" >> spokes.yaml
        echo "          - vda" >> spokes.yaml
        echo "          - vdb" >> spokes.yaml
        echo "          - vdc" >> spokes.yaml
        echo "          - vdd" >> spokes.yaml
    done
    
    # Add the single worker
    worker=0
    WORKERUID=$(kcli info vm spoke${spoke}-cluster-w${worker} -f id -v)

    echo "      worker${worker}: " >> spokes.yaml
    echo "        nic_ext_dhcp: enp1s0" >> spokes.yaml
    echo "        nic_int_static: enp2s0" >> spokes.yaml
    echo "        mac_ext_dhcp: \"ee:ee:ee:${worker}${spoke}:${worker}${spoke}:${worker}e\"" >> spokes.yaml
    echo "        mac_int_static: \"aa:aa:aa:${worker}${spoke}:${worker}${spoke}:${worker}a\"" >> spokes.yaml
    echo "        bmc_url: \"redfish-virtualmedia+http://${CHANGE_IP}:8000/redfish/v1/Systems/${WORKERUID}\"" >> spokes.yaml
    echo "        bmc_user: \"amorgant\"" >> spokes.yaml
    echo "        bmc_pass: \"alknopfler\"" >> spokes.yaml
    echo "        storage_disk:" >> spokes.yaml
    echo "          - vda" >> spokes.yaml
    echo "          - vdb" >> spokes.yaml
    echo "          - vdc" >> spokes.yaml
    echo "          - vdd" >> spokes.yaml

done

kcli create dns -n bare-net api.spoke0-cluster.alklabs.com -i 192.168.150.201
kcli create dns -n bare-net api-int.spoke0-cluster.alklabs.com -i 192.168.150.201
kcli create dns -n bare-net ztpfw-registry-ztpfw-registry.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net ztpfw-ui-ztpfw-ui.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net edge-cluster-setup.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net ztpfw-registry-quay-ztpfw-registry.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net noobaa-mgmt-openshift-storage.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net console-openshift-console.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net oauth-openshift.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net prometheus-k8s-openshift-monitoring.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
kcli create dns -n bare-net httpd-server.apps.spoke0-cluster.alklabs.com -i 192.168.150.200
echo ">>>> EOF"
echo ">>>>>>>>"
