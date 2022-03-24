import { Ingress, IngressVersion, PatchType } from '../frontend-shared';
import { getClusterApiUrl, jsonPatch, jsonRequest } from '../k8s';

export const getIngressConfig = (token: string) =>
  jsonRequest<Ingress>(`${getClusterApiUrl()}/apis/${IngressVersion}/ingresses/cluster`, token);

export const patchIngressConfig = (token: string, patches: PatchType[]) =>
  jsonPatch<Ingress>(
    `${getClusterApiUrl()}/apis/${IngressVersion}/ingresses/cluster`,
    patches,
    token,
  );
