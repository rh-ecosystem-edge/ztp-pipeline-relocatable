import { getClusterApiUrl, jsonPatch, jsonRequest } from '../k8s';
import { Metadata } from './metadata';
import { PatchType } from './patches';
import { IResource } from './resource';

export type IngressVersionType = 'config.openshift.io/v1';
export const IngressVersion: IngressVersionType = 'config.openshift.io/v1';

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
  message?: string; // for Patch
  spec?: {
    domain?: string;
    componentRoutes?: ComponentRoute[];
  };
}

export const getIngressConfig = (token: string) =>
  jsonRequest<Ingress>(`${getClusterApiUrl()}/apis/${IngressVersion}/ingresses/cluster`, token);

export const patchIngressConfig = (token: string, patches: PatchType[]) => 
  jsonPatch<Ingress>(`${getClusterApiUrl()}/apis/${IngressVersion}/ingresses/cluster`, patches, token);

