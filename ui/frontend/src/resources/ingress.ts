import { Ingress, IngressKind, IngressPlural, IngressVersion } from '../common';
import { getResource } from './resource-request';

export const getIngressConfig = () =>
  getResource<Ingress>({
    apiVersion: IngressVersion,
    kind: IngressKind,
    plural: IngressPlural,
    metadata: {
      name: 'cluster',
    },
  });
