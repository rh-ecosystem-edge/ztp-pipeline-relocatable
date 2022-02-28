import { getResource } from './resource-request';
import { Metadata } from './metadata';
import { IResource } from './resource';

export type OAuthApiVersionType = 'config.openshift.io/v1';
export const OAuthApiVersion: OAuthApiVersionType = 'config.openshift.io/v1';

// /apis/config.openshift.io/v1/oauths/cluster
// /apis/config.openshift.io/v1/oauths/cluster
// /apis/config.openshift.io/v1/oauths/cluster
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
