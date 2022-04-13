#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

usage() { echo "Usage: $0 <pull-secret-file> <ocp-version(4.10.6)> <acm_version(2.4)> <ocs_version(4.8)> <hub_architecture(installer|sno)>" 1>&2; exit 1; }

if [ $# -lt 4 ]; then
    usage
fi

export pull_secret=${1}
export ocp_version=${2}
export acm_version=${3}
export ocs_version=${4}

if [ -z "${pull_secret}" ] || [ -z "${ocp_version}" ] || [ -z "${acm_version}" ] || [ -z "${ocs_version}" ]; then
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
export VERSION="stable"
export CLUSTERS=1
export OC_PULL_SECRET="'$(cat $pull_secret)'"
export OC_OCP_VERSION="${ocp_version}"
export OC_ACM_VERSION="${acm_version}"
export OC_OCS_VERSION="${ocs_version}"
export HUB_ARCHITECTURE="${5:-installer}"
# export DEPLOY_KCLI_PLAN_COMMIT="master"


echo ">>>> Set the Pull Secret"
echo ">>>>>>>>>>>>>>>>>>>>>>>>"
echo $OC_PULL_SECRET | tr -d [:space:] | sed -e 's/^.//' -e 's/.$//' >./openshift_pull.json

echo ">>>> kcli create plan"
echo ">>>>>>>>>>>>>>>>>>>>>"

if [ "${HUB_ARCHITECTURE}" = "sno" ]; then
  echo "SNO + Metal3 + Ipv4 + connected"
  t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}')
  kcli delete vm test-ci-sno -y || true
  kcli delete network bare-net -y || true
  kcli create network --nodhcp --domain ztpfw -c 192.168.7.0/24 ztpfw
  kcli create network  -c 192.168.150.0/24 bare-net
  echo kcli create cluster openshift --force --paramfile=sno-metal3.yml -P disconnected="false" -P version="${VERSION}" -P tag="${t}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
  kcli create cluster openshift --force --paramfile=sno-metal3.yml -P version="${VERSION}" -P tag="${t}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
  export KUBECONFIG=/root/.kcli/clusters/test-ci/auth/kubeconfig
  oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": false}]'
else
  echo "Metal3 + Ipv4 + connected"
  [ -d kcli-openshift4-baremetal ] && rm -rf kcli-openshift4-baremetal
  echo "Cloning kcli-openshift4-baremetal repo"
  git clone https://github.com/karmab/kcli-openshift4-baremetal
  cp openshift_pull.json kcli-openshift4-baremetal
  git -C kcli-openshift4-baremetal checkout ${DEPLOY_KCLI_PLAN_COMMIT:-master}
  t=$(echo "${OC_RELEASE}" | awk -F: '{print $2}' | awk -F- '{print $1}')
  git pull
  kcli create network --nodhcp --domain ztpfw -c 192.168.7.0/24 ztpfw
  kcli create plan -f kcli-openshift4-baremetal --force --paramfile=lab-metal3.yml -P disconnected="false" -P version="${VERSION}" -P tag="${t}" -P openshift_image="${OC_RELEASE}" -P cluster="${OC_CLUSTER_NAME}" "${OC_CLUSTER_NAME}"
fi

echo ">>>> Spokes.yaml file generation"

#Empty file before we start
>spokes.yaml

cat <<EOF >>spokes.yaml
config:
  OC_OCP_VERSION: '${OC_OCP_VERSION}'
  OC_ACM_VERSION: '${OC_ACM_VERSION}'
  OC_OCS_VERSION: '${OC_OCS_VERSION}'
EOF

# Create header for spokes.yaml
cat <<EOF >>spokes.yaml
spokes:
EOF

echo ">>>> Create the dns entries"
if [ "${HUB_ARCHITECTURE}" = "sno" ]; then
	CHANGE_IP=$(kcli info vm test-ci-sno -vf ip)
	kcli create dns -n bare-net api.test-ci.alklabs.com -i ${CHANGE_IP}
  kcli create dns -n bare-net api-int.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net console-openshift-console.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net oauth-openshift.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net prometheus-k8s-openshift-monitoring.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net multicloud-console.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net httpd-server.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net ztpfw-registry-ztpfw-registry.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net assisted-service-open-cluster-management.apps.test-ci.alklabs.com -i ${CHANGE_IP}
	kcli create dns -n bare-net assisted-service-assisted-installer.apps.test-ci.alklabs.com -i ${CHANGE_IP}

else
	kcli create dns -n bare-net httpd-server.apps.test-ci.alklabs.com -i 192.168.150.252
	kcli create dns -n bare-net ztpfw-registry-ztpfw-registry.apps.test-ci.alklabs.com -i 192.168.150.252
fi

echo ">>>> Create the PV and sushy only if SNO "
if [ "${HUB_ARCHITECTURE}" = "sno" ]; then
  ./lab-nfs.sh
  ./lab-sushy.sh
fi
echo ">>>> EOF"
echo ">>>>>>>>"
