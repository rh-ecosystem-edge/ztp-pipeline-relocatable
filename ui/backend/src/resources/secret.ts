import { getClusterApiUrl, jsonPost } from '../k8s';
import { Metadata } from './metadata';
import { IResource } from './resource';
import { TLS_SECRET } from './resourceTemplates';

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
    'tls.crt'?: string;
    'tls.key'?: string;
  };
  type?: string;
}

export const createSecret = (token: string, object: Secret) =>
  jsonPost<Secret>(
    `${getClusterApiUrl()}/api/${SecretApiVersion}/namespaces/${
      TLS_SECRET.metadata.namespace
    }/secrets`,
    object,
    token,
  );
