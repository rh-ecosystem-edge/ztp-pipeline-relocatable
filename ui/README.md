# The KubeFrame
Configuration user interface for the KubeFrame.

## Development
To run the app in the development mode:
```
# one-time action
yarn install
```

Followed by:
```
oc login [state additional login params here]
yarn setup
source ./backend/envs
yarn start
```

### Additional scripts
```
yarn lint
yarn prettier
cd frontend && yarn test
```

Open [http://localhost:3000](http://localhost:3000) to view it in the browser.

## Build
For productoin build:
```
yarn install
yarn build
```

## Build container
To create a container image with both backend and frontend:
```
IMAGE=quay.io/mlibra/kubeframe:latest
podman build . -f Dockerfile -t ${IMAGE}
podman push ${IMAGE}
```

## Deploy container to an OpenShift cluster
To generate self-signed TLS certificates and deploy the image to an OCP cluster:
```
oc login [state additional login params here]
yarn deployprod
```

## Run container locally:
```
oc login [state additional login params here]
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
```

## Authors
Marek Libra <mlibra@redhat.com>

