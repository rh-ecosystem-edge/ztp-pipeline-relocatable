#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m



if ./verify.sh; then
    # Load common vars
    source ${WORKDIR}/shared-utils/common.sh
    echo ">>>> Deploy manifests to create template namespace on HUB Cluster"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

    ##############################################################################
    # Here can be added other manifests to create the required resources
    ##############################################################################
    ### TEMPORARY FIX: 
    dnf install -y python3-pip 
    pip3 install ansible 
    ansible -v

    ##############################################################################
    # End of customization
    ##############################################################################

fi

echo ">>>>EOF"
echo ">>>>>>>"
