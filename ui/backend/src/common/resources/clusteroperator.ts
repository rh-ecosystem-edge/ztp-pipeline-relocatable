import { Metadata } from './metadata';
import { IResource } from './resource';
import { StatusCondition } from './statuscondition';

export type ClusterOperatorApiVersionType = 'config.openshift.io/v1';
export const ClusterOperatorApiVersion: ClusterOperatorApiVersionType = 'config.openshift.io/v1';

export type ClusterOperatorKindType = 'ClusterOperator';
export const ClusterOperatorKind: ClusterOperatorKindType = 'ClusterOperator';

export interface ClusterOperator extends IResource {
  apiVersion: ClusterOperatorApiVersionType;
  kind: ClusterOperatorKindType;
  metadata: Metadata;
  status?: {
    conditions: StatusCondition[];
  };
}
