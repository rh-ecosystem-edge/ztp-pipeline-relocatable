import {
  NodeNetworkConfigurationPolicy,
  PatchType,
  NodeNetworkConfigurationPolicyApiVersion,
} from '../frontend-shared';
import { getClusterApiUrl, jsonPatch, jsonPost } from '../k8s';

const getNNCPUrl = () =>
  `${getClusterApiUrl()}/apis/${NodeNetworkConfigurationPolicyApiVersion}/nodenetworkConfigurationPolicies`;

export const createNodeNetworkConfigurationPolicy = (
  token: string,
  nncp: NodeNetworkConfigurationPolicy,
) => jsonPost<NodeNetworkConfigurationPolicy>(getNNCPUrl(), nncp, token);

export const patchNodeNetworkConfigurationPolicy = (
  token: string,
  metadata: { name: string },
  patches: PatchType[],
) => jsonPatch<NodeNetworkConfigurationPolicy>(`${getNNCPUrl()}/${metadata.name}`, patches, token);
