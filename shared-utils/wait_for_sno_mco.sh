#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -m

tput setab 7
tput setaf 4

echo ">>>> Verify the api active until mco restart node"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
retry=1
  while [ ${retry} != 0 ]; do
    oc --kubeconfig=${KUBECONFIG} get nodes &> /dev/null
    if [[ $? == 0 ]]; then
       echo "Api is up...waiting until mco will restart the node"
       sleep 10
       retry=$((retry + 1))
    else
       echo ">>>> API is down...The Cluster is restarting"
       retry=0
    fi
  done

echo ">>>> Wait until sno is restarted"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
retry=1
  while [ ${retry} != 0 ]; do
    oc --kubeconfig=${KUBECONFIG} get nodes &> /dev/null
    if [[ $? != 0 ]]; then
        echo "Api is down...waiting until node will be restarted"
        sleep 10
        retry=$((retry + 1))
    else
        echo ">>>> API is up again...The Cluster is restarted"
        retry=0
    fi
  done

echo ">>>> Launch again the pipeline"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
make deploy-pipe-hub-sno

