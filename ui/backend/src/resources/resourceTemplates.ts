import { Secret, SecretApiVersion, SecretKind, TLS_SECRET_NAMESPACE } from '../frontend-shared';

export const TLS_SECRET: Secret = {
  apiVersion: SecretApiVersion,
  data: {
    'tls.crt': '', // To be filled
    'tls.key': '', // To be filled
  },
  kind: SecretKind,
  metadata: {
    generateName: 'api-secret',
    namespace: TLS_SECRET_NAMESPACE,
  },
  type: 'kubernetes.io/tls',
};
