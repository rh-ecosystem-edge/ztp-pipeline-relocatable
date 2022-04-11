import { Secret, SecretApiVersion } from '../frontend-shared';
import { getClusterApiUrl, jsonPost } from '../k8s';
import { TLS_SECRET } from './resourceTemplates';

export const createSecret = (token: string, object: Secret) =>
  jsonPost<Secret>(
    `${getClusterApiUrl()}/api/${SecretApiVersion}/namespaces/${
      TLS_SECRET.metadata.namespace || 'unknown-namespace'
    }/secrets`,
    object,
    token,
  );
