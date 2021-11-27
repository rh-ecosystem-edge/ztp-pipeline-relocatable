#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
set -m

## variables
## #########
SPOKE="$1"
wait_time=3600

echo ">>>> Wait for bmh of spoke $SPOKE"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

echo ">>>> Wait for deployment of spoke $SPOKE"
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"

timeout=0
completed=false
failed=false
while [ "$timeout" -lt "3600" ] ; do
  MSG=$(oc get agentclusterinstall -n $SPOKE $SPOKE -o jsonpath={'.status.conditions[-1].message'})
  echo $MSG | grep completed && completed=true && break;
  echo $MSG | grep failed && failed=true && break;
  echo "Waiting for spoke cluster to be deployed"
  sleep 60
  timeout=$(($timeout + 5))
done
if [ "$completed" == "true" ] ; then
 echo "Cluster deployed"
elif [ "$failed" == "true" ] ; then
 echo Hit issue during deployment
 echo message: $MSG
 exit 1
else
 echo Timeout waiting for spoke cluster to be deployed
 exit 1
fi

echo ">>>>EOF"
echo ">>>>>>>"
