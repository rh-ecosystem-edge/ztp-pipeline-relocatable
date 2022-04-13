import { Ingress, IngressKind, IngressPlural, IngressVersion } from '../backend-shared';
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
