import { Metadata } from './metadata';
import { IResource } from './resource';

export type IngressVersionType = 'config.openshift.io/v1';
export const IngressVersion: IngressVersionType = 'config.openshift.io/v1';

export type IngressKindType = 'Ingress';
export const IngressKind: IngressKindType = 'Ingress';

export type IngressPluralType = 'ingresses';
export const IngressPlural: IngressPluralType = 'ingresses';
export interface ComponentRoute {
  hostname: string;
  name: string;
  namespace: string;
  servingCertKeyPairSecret: { name: string };
}

export interface Ingress extends IResource {
  apiVersion: IngressVersionType;
  kind: IngressKindType;
  plural: IngressPluralType;
  metadata: Metadata;
  message?: string; // for Patch
  spec?: {
    domain?: string;
    componentRoutes?: ComponentRoute[];
  };
  status?: {
    componentRoutes?: {
      name: string;
      namespace: string;
      defaultHostname?: string;
      currentHostnames?: string[];
    }[];
  };
}
