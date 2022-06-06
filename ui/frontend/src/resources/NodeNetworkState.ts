import { listClusterResources } from './resource-request';
import {
  NodeNetworkState,
  NodeNetworkStateKind,
  NodeNetworkStateApiVersion,
} from '../backend-shared';

export const getNodeNetworkStates = () =>
  listClusterResources<NodeNetworkState>({
    apiVersion: NodeNetworkStateApiVersion,
    kind: NodeNetworkStateKind,
  });
