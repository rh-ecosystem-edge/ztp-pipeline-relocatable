#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
export DEPLOY_OCP_DIR="./"
export OC_RELEASE="quay.io/openshift-release-dev/ocp-release:4.9.13-x86_64"
export OC_CLUSTER_NAME="test-ci"
export OC_DEPLOY_METAL="yes"
export OC_NET_CLASS="ipv4"
export OC_TYPE_ENV="connected"
export VERSION="ci"


if [ $# -eq 0 ]; then
  echo "No arguments supplied. Usage $0 <pull-secret.json> [<clusters-number>]"
  echo "  - Params:"
  echo "    1 - Pull secret file path (Mandatory)"
  echo "    2 - Clusters Spokes number to deploy (Optional: default 1)"
  exit 1
fi
if [ $2 != "" ]; then
    export CLUSTERS=$2
else
    export CLUSTERS=0
fi

export OC_PULL_SECRET="'$(cat $1)'"

# Only complain when there's less than one cluster
if [ ${CLUSTERS} -lt 0 ]; then
    echo "Usage: $0 <# of clusters>"
    exit 1
fi

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
            git pull
            kcli create network --nodhcp --domain kubeframe -c 192.168.7.0/24 kubeframe
            kcli create plan --force --paramfile=lab-metal3.yml -P disconnected="false" -P version="${VERSION}" -P tag="${t}" -P openshift_image="${OC_RELEASE}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
        else
            echo "Metal3 + ipv4 + disconnected"
            t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
            kcli create plan --force --paramfile=lab-metal3.yml -P disconnected="true" -P version="${VERSION}" -P tag="${t}" -P openshift_image="${OC_RELEASE}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
        fi
    else
        echo "Metal3 + ipv6 + disconnected"
        t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
        kcli create plan --force --paramfile=lab_ipv6.yml -P disconnected="true" -P version="${VERSION}" -P tag="${t}" -P openshift_image="${OC_RELEASE}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"

    fi
else
    echo "Without Metal3 + ipv4 + connected"
    kcli create kube openshift --force --paramfile lab-withoutMetal3.yml -P tag="${OC_RELEASE}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
fi

# Spokes.yaml file generation

#Empty file before we start

>spokes.yaml

CHANGE_IP=$(kcli info vm test-ci-installer | grep ip | awk '{print $2}')
# Default configuration
cat <<EOF >>spokes.yaml
config:
  clusterimageset: 'openshift-v4.9.13'
  OC_OCP_VERSION: '4.9'
  OC_OCP_TAG: '4.9.13-x86_64'
  OC_RHCOS_RELEASE: '49.84.202110081407-0'  # TODO automate it to get it automated using binary
  OC_ACM_VERSION: '2.4'
  OC_OCS_VERSION: '4.8'
EOF

# Create header for spokes.yaml
cat <<EOF >>spokes.yaml
spokes:
EOF

kcli create dns -n bare-net httpd-server.apps.test-ci.alklabs.com -i 192.168.150.252
kcli create dns -n bare-net kubeframe-registry-kubeframe-registry.apps.test-ci.alklabs.com -i 192.168.150.252

echo ">>>> EOF"
echo ">>>>>>>>"
