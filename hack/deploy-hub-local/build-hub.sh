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
export VERSION="stable"
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

                echo "SNO + Metal3 + Ipv4 + connected"
                t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
                kcli delete vm test-ci-sno -y || true; kcli delete network bare-net -y || true
                kcli create network --nodhcp -c 192.168.7.0/24 ztpfw -i
                kcli create network -c 192.168.150.0/24 bare-net
                echo kcli create cluster openshift --force --paramfile=hub-install.yml -P masters=1 -P memory=40000 -P version="${VERSION}" -P tag="${t}"  "${OC_CLUSTER_NAME}"
                kcli create cluster openshift --force --paramfile=hub-install.yml -P masters=1 -P memory=40000 -P version="${VERSION}" -P tag="${t}"  "${OC_CLUSTER_NAME}"
                export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
                oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
            else
                echo "Multinode + Metal3 + Ipv4 + connected"
             	t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
             	kcli delete vm test-ci-sno -y || true; kcli delete network bare-net -y || true
             	kcli create network --nodhcp --domain ztpfw -c 192.168.7.0/24 ztpfw
             	kcli create network  -c 192.168.150.0/24 bare-net
             	echo kcli create cluster openshift --force --paramfile=hub-install.yml -P masters=3 -P memory=32000 -P disconnected="false" -P version="${VERSION}" -P tag="${t}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
             	kcli create cluster openshift --force --paramfile=hub-install.yml -P masters=3 -P memory=32000 -P version="${VERSION}" -P tag="${t}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
             	export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
             	oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
            fi
        fi
    fi
fi

echo ">>>> Spokes.yaml file generation"

#Empty file before we start
>spokes.yaml

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

echo ">>>> Create the PV and sushy and dns"
./lab-nfs.sh
./lab-sushy.sh

echo ">>>> EOF"
echo ">>>>>>>>"
