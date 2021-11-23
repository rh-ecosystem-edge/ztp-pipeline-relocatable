#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
export DEPLOY_OCP_DIR="./lab-kcli-ipi-baremetal"
export OC_AMORGANT_PULL_SECRET='"{"auths": ... }"'
export OC_RELEASE="quay.io/openshift-release-dev/ocp-release:4.9.0-x86_64"
export OC_CLUSTER_NAME="test-ci"
export OC_DEPLOY_METAL="yes"
export OC_NET_CLASS="ipv4"
export OC_TYPE_ENV="connected"
export VERSION="ci"

echo ">>>> Set the Pull Secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"

echo $OC_AMORGANT_PULL_SECRET | tr -d [:space:] | sed -e 's/^.//' -e 's/.$//' > ./openshift_pull.json


echo ">>>> kcli create plan"
echo ">>>>>>>>>>>>>>>>>>>>>"


if [ "$OC_DEPLOY_METAL" = "yes" ]; then
    if [ "$OC_NET_CLASS" = "ipv4"  ]; then
        if [ "$OC_TYPE_ENV" = "connected" ] ; then
            echo "Metal3 + Ipv4 + connected"
            t=$(echo "$OC_RELEASE" | awk -F: '{print $2}')
            kcli create plan --force --paramfile=lab-metal3.yml -P disconnected="false" -P version="$VERSION" -P tag="$t" -P openshift_image="$OC_RELEASE" -P cluster="$OC_CLUSTER_NAME" "$OC_CLUSTER_NAME"

        else
            echo "Metal3 + ipv4 + disconnected"
            t=$(echo "$OC_RELEASE" | awk -F: '{print $2}')
            kcli create plan --force --paramfile=lab-metal3.yml -P disconnected="true" -P version="$VERSION" -P tag="$t" -P openshift_image="$OC_RELEASE" -P cluster="$OC_CLUSTER_NAME" "$OC_CLUSTER_NAME"
        fi
    else
        echo "Metal3 + ipv6 + disconnected"
        t=$(echo "$OC_RELEASE" | awk -F: '{print $2}')
        kcli create plan --force --paramfile=lab_ipv6.yml -P disconnected="true" -P version="$VERSION" -P tag="$t" -P openshift_image="$OC_RELEASE" -P cluster="$OC_CLUSTER_NAME" "$OC_CLUSTER_NAME"

    fi
else
   echo "Without Metal3 + ipv4 + connected"
   kcli create kube openshift --force --paramfile lab-withoutMetal3.yml -P tag="$OC_RELEASE" -P cluster="$OC_CLUSTER_NAME" "$OC_CLUSTER_NAME"
fi

echo ">>>> EOF"
echo ">>>>>>>>"