---
modified: 2022-03-09T11:10:44.009Z
---

# The Edge Cluster configuration User Interface

Configuration user interface for the ZTPFW.

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
