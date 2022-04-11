import { PatchType, Route, RouteApiVersion } from '../frontend-shared';
import { getClusterApiUrl, jsonPatch, jsonRequest } from '../k8s';
import { ListResult } from './types';

export const getAllRoutes = async (token: string) =>
  (
    await jsonRequest<ListResult<Route>>(
      `${getClusterApiUrl()}/apis/${RouteApiVersion}/routes?limit=50000`,
      token,
    )
  ).items;

// https://api.spoke0-cluster.alklabs.com:6443/apis/route.openshift.io/v1/namespaces/ztpfw-ui/routes/ztpfw-ui
export const patchRoute = (
  token: string,
  metadata: { name: string; namespace: string },
  patches: PatchType[],
) =>
  jsonPatch<Route>(
    `${getClusterApiUrl()}/apis/${RouteApiVersion}/namespaces/${metadata.namespace}/routes/${
      metadata.name
    }`,
    patches,
    token,
  );
