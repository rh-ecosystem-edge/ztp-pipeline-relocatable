#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

# variables
# #########
# uncomment it, change it or get it from gh-env vars (default behaviour: get from gh-env)
# export KUBECONFIG=/root/admin.kubeconfig

function extract_kubeconfig() {
    ## Extract the Spoke kubeconfig and put it on the shared folder
    export SPOKE_KUBECONFIG=${OUTPUTDIR}/kubeconfig-${1}
    oc --kubeconfig=${KUBECONFIG_HUB} extract -n $spoke secret/$spoke-admin-kubeconfig --to - > ${SPOKE_KUBECONFIG}
}

# Load common vars
source ${WORKDIR}/shared-utils/common.sh
if [[ -z ${ALLSPOKES} ]]; then
	ALLSPOKES=$(yq e '(.spokes[] | keys)[]' ${SPOKES_FILE})
fi

for spoke in ${ALLSPOKES}; do
	echo ">>>> Deploy manifests to install LSO and LocalVolume: ${spoke}"
	echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	echo "Extract Kubeconfig for ${spoke}"
	extract_kubeconfig ${spoke}
	if [[ $(oc get --kubeconfig=${SPOKE_KUBECONFIG} pod -n openshift-storage | grep -i running | wc -l) -ne $(oc --kubeconfig=${SPOKE_KUBECONFIG} get pod -n openshift-storage --no-headers | grep -v Completed| wc -l) ]]; then

	#ocs in the spoke not exists so we need to create it
	exit 1
	fi
done

echo ">>>>EOF"
echo ">>>>>>>"
