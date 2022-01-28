#!/bin/bash

podman build . -f Dockerfile -t kubeframe:test

yarn setup
source backend/envs
export BACKEND_PORT=3000

podman run -t -p 3000:3000/tcp \
  --env BACKEND_PORT \
  --env FRONTEND_URL \
  --env CLUSTER_API_URL \
  --env TOKEN \
  --env OAUTH2_CLIENT_ID \
  --env OAUTH2_CLIENT_SECRET \
  --env OAUTH2_REDIRECT_URL \
   kubeframe:test

