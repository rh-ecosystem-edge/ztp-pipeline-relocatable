import { Metadata } from './metadata';
import { IResource } from './resource';

export type RouteApiVersionType = 'route.openshift.io/v1';
export const RouteApiVersion: RouteApiVersionType = 'route.openshift.io/v1';

export type RouteKindType = 'Route';
export const RouteKind: RouteKindType = 'Route';

export interface Route extends IResource {
  apiVersion: RouteApiVersionType;
  kind: RouteKindType;
  metadata: Metadata;
  spec?: {
    host?: string;
    port?: unknown;
    tls?: unknown;
    to?: unknown;
    wildcardPolicy?: unknown;
  };
}
