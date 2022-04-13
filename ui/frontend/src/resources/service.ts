import { getResource } from './resource-request';
import { Service, ServiceApiVersion, ServiceKind } from '../backend-shared';

export const getService = (metadata: { name: string; namespace: string }) =>
  getResource<Service>({
    apiVersion: ServiceApiVersion,
    kind: ServiceKind,
    metadata,
  });
