import {
  NodeNetworkConfigurationPolicy,
  PatchType,
  NodeNetworkConfigurationPolicyApiVersion,
} from '../frontend-shared';
import { getClusterApiUrl, jsonPatch } from '../k8s';

export const patchNodeNetworkConfigurationPolicy = (
  token: string,
  metadata: { name: string },
  patches: PatchType[],
) =>
  jsonPatch<NodeNetworkConfigurationPolicy>(
    `${getClusterApiUrl()}/apis/${NodeNetworkConfigurationPolicyApiVersion}/nodenetworkConfigurationPolicies/${
      metadata.name
    }`,
    patches,
    token,
  );
