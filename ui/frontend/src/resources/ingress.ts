import { Ingress, IngressKind, IngressVersion } from '../common';
import { getResource } from './resource-request';

export const getIngressConfig = () =>
  getResource<Ingress>({
    apiVersion: IngressVersion,
    kind: IngressKind,
    metadata: {
      name: 'cluster',
    },
  });
