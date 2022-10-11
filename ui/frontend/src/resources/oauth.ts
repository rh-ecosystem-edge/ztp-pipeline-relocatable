import { Metadata, IResource, IDENTITY_PROVIDER_NAME } from '../backend-shared';
import { getBackendUrl, getRequest, getResource } from './resource-request';

export type OAuthApiVersionType = 'config.openshift.io/v1';
export const OAuthApiVersion: OAuthApiVersionType = 'config.openshift.io/v1';

export type OAuthKindType = 'OAuth';
export const OAuthKind: OAuthKindType = 'OAuth';

export type IndetityProviderType = {
  name: string;
  mappingMethod: 'claim';
  type: 'HTPasswd';
  htpasswd: {
    fileData: {
      name: string; // secret name
    };
  };
};

export interface OAuth extends IResource {
  apiVersion: OAuthApiVersionType;
  kind: OAuthKindType;
  metadata: Metadata;
  spec?: {
    identityProviders: IndetityProviderType[];
  };
}

export const getOAuth = () =>
  getResource<OAuth>({
    apiVersion: OAuthApiVersion,
    kind: OAuthKind,
    metadata: {
      name: 'cluster',
    },
  });

export const getHtpasswdIdentityProvider = (oauth?: OAuth): IndetityProviderType | undefined =>
  oauth?.spec?.identityProviders?.find((ip) => ip.name === IDENTITY_PROVIDER_NAME);

export const getLoggedInUser = () =>
  getRequest<{
    body: {
      username: string;
    };
    statusCode: number;
  }>(`${getBackendUrl()}/user`).promise;

export const isKubeAdmin = async (): Promise<boolean | undefined> => {
  const username = (await getLoggedInUser())?.body?.username;
  if (!username) {
    return undefined;
  }

  return username === 'kube:admin';
};
