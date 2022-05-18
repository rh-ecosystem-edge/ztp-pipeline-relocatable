import { listClusterResources, getResource } from './resource-request';
import { ClusterOperator, ClusterOperatorApiVersion, ClusterOperatorKind } from '../backend-shared';

export const getClusterOperators = () =>
  listClusterResources<ClusterOperator>({
    apiVersion: ClusterOperatorApiVersion,
    kind: ClusterOperatorKind,
  });

export const getClusterOperator = (name: string) =>
  getResource<ClusterOperator>({
    apiVersion: ClusterOperatorApiVersion,
    kind: ClusterOperatorKind,
    metadata: {
      name,
    },
  });
