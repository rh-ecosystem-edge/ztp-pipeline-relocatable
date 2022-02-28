#!/bin/bash

IMAGE=quay.io/mlibra/kubeframe:latest
podman build . -f Dockerfile -t ${IMAGE}
podman push ${IMAGE}

exit 1

# run locally
# TODO: handle TLS cert
yarn setup
source backend/envs
export BACKEND_PORT=3000
podman run -t -p 3000:3000/tcp \
  --env BACKEND_PORT \
  --env CLUSTER_API_URL \
  --env FRONTEND_URL \
  --env TOKEN \
  --env OAUTH2_CLIENT_ID \
  --env OAUTH2_CLIENT_SECRET \
  --env OAUTH2_REDIRECT_URL \
  ${IMAGE}

