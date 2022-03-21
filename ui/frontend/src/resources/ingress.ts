import { getResource } from './resource-request';
import { Metadata } from './metadata';
import { IResource } from './resource';

export type IngressVersionType = 'ingress.config.openshift.io/v1';
export const IngressVersion: IngressVersionType = 'ingress.config.openshift.io/v1';

export type IngressKindType = 'Ingress';
export const IngressKind: IngressKindType = 'Ingress';

export interface ComponentRoute {
  hostname: string;
  name: string;
  namespace: string;
  servingCertKeyPairSecret: { name: string };
}

export interface Ingress extends IResource {
  apiVersion: IngressVersionType;
  kind: IngressKindType;
  metadata: Metadata;
  spec?: {
    domain?: string;
    componentRoutes?: ComponentRoute[];
  };
}

export const getIngressConfig = () =>
  getResource<Ingress>({
    apiVersion: IngressVersion,
    kind: IngressKind,
    metadata: {
      name: 'cluster',
    },
  });
