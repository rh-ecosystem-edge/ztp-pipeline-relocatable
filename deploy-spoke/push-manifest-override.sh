#!/usr/bin/env bash
# Description: Pushes custom manifests to force InfrastructureTopology HighlyAvailable

set -o pipefail
set -o nounset
set -m

export folder=manifests
export ASSISTED_SERVICE_HOST=https://assisted-service-open-cluster-management.apps.test-ci.alklabs.com
export CLUSTER_ID="null"

while [ ${CLUSTER_ID} == "null" ]; do
	export CLUSTER_ID=$(curl -s -k ${ASSISTED_SERVICE_HOST}/api/assisted-install/v2/clusters/ | jq -r ".[0].id")
done

# Load common vars
source ${WORKDIR}/shared-utils/common.sh

retry=1
while [ ${retry} != 0 ]; do
	export file=cluster-infrastructure-02-config.yml
	export content=$(cat ${OUTPUTDIR}/manifests/${file} | base64 -w0)
	curl --fail -k \
	    --header "Content-Type: application/json" \
	    --request POST \
	    --data "{\"file_name\":\"$file\", \"folder\":\"$folder\", \"content\":\"$content\"}" \
	   "$ASSISTED_SERVICE_HOST/api/assisted-install/v2/clusters/$CLUSTER_ID/manifests" 2>&1

	EXIT=$?
	if [ ${EXIT} -eq 0 ]; then
		retry=0
	else
	    sleep 2
	    retry=$((retry + 1))
	fi
done


retry=1
while [ ${retry} != 0 ]; do
	export file=54-scheduler-override.yaml
	export content=$(cat ${WORKDIR}/deploy-spoke/${file} | base64 -w0)
	curl --fail -k \
	    --header "Content-Type: application/json" \
	    --request POST \
	    --data "{\"file_name\":\"$file\", \"folder\":\"$folder\", \"content\":\"$content\"}" \
	   "$ASSISTED_SERVICE_HOST/api/assisted-install/v2/clusters/$CLUSTER_ID/manifests" 2>&1

	EXIT=$?
	if [ ${EXIT} -eq 0 ]; then
		retry=0
	else
	    sleep 2
	    retry=$((retry + 1))
	fi
done
