import { PatchType, Deployment, DeploymentApiVersion } from '../frontend-shared';
import { getClusterApiUrl, jsonPatch, jsonRequest } from '../k8s';

// /apis/apps/v1/namespaces/ztpfw-ui/deployments/ztpfw-ui'
export const getDeployment = async (token: string, metadata: { name: string; namespace: string }) =>
  await jsonRequest<Deployment>(
    `${getClusterApiUrl()}/apis/${DeploymentApiVersion}/namespaces/${
      metadata.namespace
    }/deployments/${metadata.name}`,
    token,
  );

export const patchDeployment = (
  token: string,
  metadata: { name: string; namespace: string },
  patches: PatchType[],
) =>
  jsonPatch<Deployment>(
    `${getClusterApiUrl()}/apis/${DeploymentApiVersion}/namespaces/${
      metadata.namespace
    }/deployments/${metadata.name}`,
    patches,
    token,
  );
