import { deleteResource, getResource } from './resource-request';
import { Metadata } from './metadata';
import { IResource } from './resource';

export type SecretApiVersionType = 'v1';
export const SecretApiVersion: SecretApiVersionType = 'v1';

export type SecretKindType = 'Secret';
export const SecretKind: SecretKindType = 'Secret';

export interface Secret extends IResource {
  apiVersion: SecretApiVersionType;
  kind: SecretKindType;
  metadata: Metadata;
  data?: {
    // all base64
    htpasswd?: string;
    'id_rsa.key'?: string;
    'tls.crt'?: string;
    'tls.key'?: string;
  };
  type?: string;
}

export const getSecret = (metadata: { name: string; namespace: string }) =>
  getResource<Secret>({
    apiVersion: SecretApiVersion,
    kind: SecretKind,
    metadata,
  });

export const deleteSecret = (metadata: { name: string; namespace: string }) =>
  deleteResource<Secret>({
    apiVersion: SecretApiVersion,
    kind: SecretKind,
    metadata,
  });
