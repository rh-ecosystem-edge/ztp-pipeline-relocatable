import { Metadata } from './metadata';
import { IResource } from './resource';

export type NodeType = 'v1';
export const NodeApiVersion: NodeType = 'v1';

export type NodeKindType = 'Node';
export const NodeKind: NodeKindType = 'Node';

export interface Node extends IResource {
  apiVersion: NodeType;
  kind: NodeKindType;
  metadata: Metadata;
  /*
    node-role.kubernetes.io/master: ""
    node-role.kubernetes.io/worker: ""
  */

  status?: {
    addresses?: {
      address: string;
      type: 'Hostname' | 'InternalIP';
    }[];
  };
}
