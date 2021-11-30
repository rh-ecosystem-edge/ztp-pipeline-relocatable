#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
source ./common.sh hub

podman login ${DESTINATION_REGISTRY} -u ${REG_US} -p ${REG_PASS} --authfile=${PULL_SECRET}
for packagemanifest in $(oc get packagemanifest -n openshift-marketplace -o name ${PACKAGES_FORMATED}); do
	for package in $(oc get $packagemanifest -o jsonpath='{.status.channels[*].currentCSVDesc.relatedImages}' | sed "s/ /\n/g" | tr -d '[],' | sed 's/"/ /g'); do
		echo
		echo "Package: ${package}"
		skopeo inspect docker://${DESTINATION_REGISTRY}/${OLM_DESTINATION_REGISTRY_IMAGE_NS}/$(echo $package | awk -F'/' '{print $2}')-$(basename $package) --authfile ${PULL_SECRET}
		if [ $? -eq 0 ]; then
    #In this case, we don't need to mirror catalogs, everything is already there
      break;
		else
    #echo "Must mirror catalog...Launching step to create them"
      exit 0
    fi
	done
done
#In this case, we don't need to mirror catalogs, everything is already there
exit 1
