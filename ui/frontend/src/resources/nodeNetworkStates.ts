import { listClusterResources } from './resource-request';
import {
  NodeNetworkState,
  NodeNetworkStateApiVersion,
  NodeNetworkStateKind,
} from '../backend-shared';

export const getAllNodeNetworkStates = () =>
  listClusterResources<NodeNetworkState>({
    apiVersion: NodeNetworkStateApiVersion,
    kind: NodeNetworkStateKind,
  });
