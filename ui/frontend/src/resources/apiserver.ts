import { getResource } from './resource-request';
import { Metadata } from './metadata';
import { IResource } from './resource';

export type ApiServerVersionType = 'ingress.config.openshift.io/v1';
export const ApiServerVersion: ApiServerVersionType = 'ingress.config.openshift.io/v1';

export type ApiServerKindType = 'Ingress';
export const ApiServerKind: ApiServerKindType = 'Ingress';

export interface NamedCertificate {
  names: string[];
  servingCertificate: { name: string };
}

export interface ApiServer extends IResource {
  apiVersion: ApiServerVersionType;
  kind: ApiServerKindType;
  metadata: Metadata;
  spec?: {
    servingCerts?: { namedCertificates?: NamedCertificate[] };
  };
}

export const getApiServerConfig = () =>
  getResource<ApiServer>({
    apiVersion: ApiServerVersion,
    kind: ApiServerKind,
    metadata: {
      name: 'cluster',
    },
  });
