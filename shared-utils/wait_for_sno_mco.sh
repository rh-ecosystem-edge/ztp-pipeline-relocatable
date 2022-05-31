#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

tput setab 7
tput setaf 4

retry=1
while [ ${retry} != 0 ]; do
    oc --kubeconfig=${KUBECONFIG} get nodes &>/dev/null
    if [[ $? == 0 ]]; then
        echo "$(tput setab 7)$(tput setaf 4)[ZTPFW - Monitoring MCO - SNO]$(tput sgr 0) >>>> API is up...waiting until mco will restart the node"
        sleep 10
        retry=$((retry + 1))
    else
        echo "$(tput setab 7)$(tput setaf 4)[ZTPFW - Monitoring MCO - SNO]$(tput sgr 0) >>>> API is down...The Cluster is restarting"
        retry=0
    fi
done

retry=1
while [ ${retry} != 0 ]; do
    oc --kubeconfig=${KUBECONFIG} get nodes &>/dev/null
    if [[ $? != 0 ]]; then
        echo "$(tput setab 7)$(tput setaf 4)[ZTPFW - Monitoring MCO - SNO]$(tput sgr 0) >>>> Api is down...waiting until node will be restarted"
        sleep 10
        retry=$((retry + 1))
    else
        echo "$(tput setab 7)$(tput setaf 4)[ZTPFW - Monitoring MCO - SNO]$(tput sgr 0) >>>> API is up again...The Cluster is restarted"
        retry=0
    fi
done

sleep 120
echo "$(tput setab 7)$(tput setaf 4)[ZTPFW - Monitoring MCO - SNO]$(tput sgr 0) >>>> Relaunch again the pipeline"
make deploy-pipe-hub-sno
