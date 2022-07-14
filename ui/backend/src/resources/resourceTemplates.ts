import { TLS_SECRET_NAMESPACE } from '../constants';
import {
  Secret,
  SecretApiVersion,
  SecretKind,
  NodeNetworkConfigurationPolicy,
} from '../frontend-shared';

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

export const NNCP_TEMPLATE: NodeNetworkConfigurationPolicy = {
  // TODO
};
