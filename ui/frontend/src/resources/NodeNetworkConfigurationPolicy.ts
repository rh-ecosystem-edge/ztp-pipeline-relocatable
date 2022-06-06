import { listClusterResources } from './resource-request';
import {
  NodeNetworkConfigurationPolicyApiVersion,
  NodeNetworkConfigurationPolicyKind,
  NodeNetworkConfigurationPolicy,
} from '../backend-shared';

export const getNodeNetworkConfigurationPolicies = () =>
  listClusterResources<NodeNetworkConfigurationPolicy>({
    apiVersion: NodeNetworkConfigurationPolicyApiVersion,
    kind: NodeNetworkConfigurationPolicyKind,
  });
