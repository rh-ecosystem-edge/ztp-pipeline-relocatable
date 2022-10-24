import { listClusterResources } from './resource-request';
import { Node, NodeApiVersion, NodeKind } from '../backend-shared';

export const getAllNodes = () =>
  listClusterResources<Node>({
    apiVersion: NodeApiVersion,
    kind: NodeKind,
  });
