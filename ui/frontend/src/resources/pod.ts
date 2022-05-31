import { listNamespacedResources } from './resource-request';
import { Pod, PodApiVersion, PodKind } from '../backend-shared';

export const getPodsOfNamespace = (namespace: string) =>
  listNamespacedResources<Pod>({
    apiVersion: PodApiVersion,
    kind: PodKind,
    metadata: { namespace },
  });
