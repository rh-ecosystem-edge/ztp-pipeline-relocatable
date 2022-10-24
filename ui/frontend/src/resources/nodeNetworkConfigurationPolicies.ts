import { listClusterResources } from './resource-request';
import {
  NodeNetworkConfigurationPolicy,
  NodeNetworkConfigurationPolicyApiVersion,
  NodeNetworkConfigurationPolicyKind,
} from '../backend-shared';

export const getAllNodeNetworkConfigurationPolicies = () =>
  listClusterResources<NodeNetworkConfigurationPolicy>({
    apiVersion: NodeNetworkConfigurationPolicyApiVersion,
    kind: NodeNetworkConfigurationPolicyKind,
  });
