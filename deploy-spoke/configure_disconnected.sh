#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

function icsp_maker() {
	# This function generated the ICSP for the current spoke

}

# variables
# #########
# Load common vars
source ${WORKDIR}/shared-utils/common.sh

oc -n ${MARKET_NS} create -f ${OUTPUTDIR}/catalogsource.yaml -o yaml --dry-run=client | oc apply -f -

icsp_maker ${OUTPUTDIR}/mapping.txt
