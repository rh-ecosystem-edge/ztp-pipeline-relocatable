import { listClusterResources } from './resource-request';
import { Node, NodeKind, NodeApiVersion } from '../backend-shared';

export const getNodes = () =>
  listClusterResources<Node>({
    apiVersion: NodeApiVersion,
    kind: NodeKind,
  });
