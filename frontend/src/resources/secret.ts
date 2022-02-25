import { getResource } from './resource-request';
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
    htpasswd: string; // base64
  };
  type?: string;
}

export const getSecret = (metadata: { name: string; namespace: string }) =>
  getResource<Secret>({
    apiVersion: SecretApiVersion,
    kind: SecretKind,
    metadata,
  });
