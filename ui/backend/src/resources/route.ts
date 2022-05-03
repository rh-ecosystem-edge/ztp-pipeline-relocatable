import { RouteKind } from '../common';
import { PatchType, Route, RouteApiVersion } from '../frontend-shared';
import { getClusterApiUrl, jsonDelete, jsonPatch, jsonPost, jsonRequest } from '../k8s';
import { ListResult } from './types';

const logger = console;

export const getAllRoutes = async (token: string) =>
  (
    await jsonRequest<ListResult<Route>>(
      `${getClusterApiUrl()}/apis/${RouteApiVersion}/routes?limit=50000`,
      token,
    )
  ).items;

const getRouteUrl = (namespace: string, name: string) =>
  `${getClusterApiUrl()}/apis/${RouteApiVersion}/namespaces/${namespace}/routes/${name}`;

export const getRoute = async (token: string, metadata: { name: string; namespace: string }) =>
  await jsonRequest<Route>(getRouteUrl(metadata.namespace, metadata.name), token);

export const patchRoute = (
  token: string,
  metadata: { name: string; namespace: string },
  patches: PatchType[],
) => jsonPatch<Route>(getRouteUrl(metadata.namespace, metadata.name), patches, token);

export const backupRoute = async (token: string, route: Route) => {
  const { namespace, name } = route.metadata;
  if (!namespace || !name) {
    logger.warn('backupRoute: no route provided');
    return;
  }

  const backupRouteName = `${name}-copy`;
  try {
    await jsonDelete<Route>(getRouteUrl(namespace, name), token);
  } catch (e) {
    console.log('Attempt to delete route-backup failed. This is not an error: ', e);
  }

  try {
    const routeCopy: Route = {
      apiVersion: RouteApiVersion,
      kind: RouteKind,
      metadata: {
        labels: route.metadata.labels,
        name: backupRouteName,
        namespace: namespace,
      },
      spec: {
        host: route.spec?.host,
        port: route.spec?.port,
        tls: route.spec?.tls,
        to: route.spec?.host,
        wildcardPolicy: route.spec?.wildcardPolicy,
      },
    };
    return await jsonPost<Route>(
      `${getClusterApiUrl()}/apis/${RouteApiVersion}/namespaces/${namespace}/routes`,
      routeCopy,
      token,
    );
  } catch (e) {
    console.error(`Failed to create copy of ${namespace}/${name} route: `, e);
  }
  return undefined;
};
