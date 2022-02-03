# Copyright Contributors to the Open Cluster Management project


#!/usr/bin/env bash

echo > ./backend/envs

echo export BACKEND_PORT=4000 >> ./backend/envs
echo export NODE_ENV=development >> ./backend/envs

CLUSTER_API_URL=`oc get infrastructure cluster -o jsonpath={.status.apiServerURL}`
echo export CLUSTER_API_URL=$CLUSTER_API_URL >> ./backend/envs

OAUTH2_CLIENT_ID=kubeframeoauth
echo export OAUTH2_CLIENT_ID=$OAUTH2_CLIENT_ID >> ./backend/envs

OAUTH2_CLIENT_SECRET=kubeframeoauthsecret
echo export OAUTH2_CLIENT_SECRET=$OAUTH2_CLIENT_SECRET >> ./backend/envs

OAUTH2_REDIRECT_URL=https://localhost:3000/login/callback
echo export OAUTH2_REDIRECT_URL=$OAUTH2_REDIRECT_URL >> ./backend/envs

#TODO: HTTPS??
#BACKEND_URL=http://localhost:4000
#echo export BACKEND_URL=$BACKEND_URL >> ./backend/envs
#echo export REACT_APP_BACKEND_PATH=${BACKEND_URL} >> ./backend/envs

FRONTEND_URL=https://localhost:3000
echo export FRONTEND_URL=$FRONTEND_URL >> ./backend/envs

#SA_SECRET=$(oc get serviceaccounts -n open-cluster-management --selector=app=console-chart,component=serviceaccount -o json | jq -r '.items[0].secrets[] | select (.name | test("-token-")).name')
#SA_TOKEN=`oc get secret -n open-cluster-management ${SA_SECRET} -o="jsonpath={.data.token}"`

echo export TOKEN=`oc whoami -t` >> ./backend/envs
#echo ${SA_TOKEN} > /tmp/tmp_SA_TOKEN
#SA_TOKEN=`cat /tmp/tmp_SA_TOKEN | base64 -d -`
#rm /tmp/tmp_SA_TOKEN
#echo TOKEN=$SA_TOKEN >> ./backend/envs

REDIRECT_URIS=$(oc get OAuthClient $OAUTH2_CLIENT_ID -o json | jq -c "[.redirectURIs[], \"$OAUTH2_REDIRECT_URL\"] | unique")
oc patch OAuthClient $OAUTH2_CLIENT_ID --type json -p "[{\"op\": \"add\", \"path\": \"/redirectURIs\", \"value\": ${REDIRECT_URIS}}]"

