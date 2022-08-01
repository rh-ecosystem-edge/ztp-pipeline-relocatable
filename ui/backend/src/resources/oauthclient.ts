import { OAuthClient, OAuthClientApiVersion, PatchType } from '../frontend-shared';
import { getClusterApiUrl, jsonPatch, jsonRequest } from '../k8s';

// apis/oauth.openshift.io/v1/oauthclients/ztpfwoauth
export const getOAuthClient = async (token: string, name: string) =>
  await jsonRequest<OAuthClient>(
    `${getClusterApiUrl()}/apis/${OAuthClientApiVersion}/oauthclients/${name}`,
    token,
  );

export const patchOAuthClient = (token: string, name: string, patches: PatchType[]) =>
  jsonPatch<OAuthClient>(
    `${getClusterApiUrl()}/apis/${OAuthClientApiVersion}/oauthclients/${name}`,
    patches,
    token,
  );
