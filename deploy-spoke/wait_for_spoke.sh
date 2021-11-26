#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

# variables
# #########
SPOKE="$1"
wait_time=3600

echo ">>>> Wait for bmh of spoke $SPOKE"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"



echo ">>>> Wait for deployment of spoke $SPOKE"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

timeout=0
ready=false
while [ "$timeout" -lt "$wait_time" ] ; do
  SPOKE_STATUS=$(oc get -n $SPOKE AgentClusterInstall $SPOKE -o jsonpath='{.status.debugInfo.state}')
  test "$SPOKE_STATUS" == "installed" && ready=true && break;
  echo "Waiting for spoke cluster $SPOKE to be deployed"
  sleep 60
  timeout=$(($timeout + 5))
done
if [ "$ready" == "false" ] ; then
 echo timeout waiting for spoke cluster $SPOKE to be deployed
 exit 1
else
 echo cluster $SPOKE deployed
fi
echo ">>>>EOF"
echo ">>>>>>>"
