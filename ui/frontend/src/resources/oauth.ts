import { getResource } from './resource-request';
import { Metadata, IResource } from '../common';
import { IDENTITY_PROVIDER_NAME } from '../components/PersistPage/constants';

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
