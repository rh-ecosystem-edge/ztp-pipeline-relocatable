import { IResource, Metadata, RouteApiVersion, RouteKind } from '../backend-shared';
import { deleteResource } from './resource-request';

export interface Route extends IResource {
  apiVersion: 'route.openshift.io/v1';
  kind: 'Route';
  metadata: Metadata;
  spec?: {
    host?: string;
  };
}

export const deleteRoute = (metadata: { name: string; namespace: string }) =>
  deleteResource<Route>({
    apiVersion: RouteApiVersion,
    kind: RouteKind,
    metadata,
  });
