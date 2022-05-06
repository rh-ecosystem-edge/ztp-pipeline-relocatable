import { Metadata } from './metadata';
import { IResource } from './resource';

// apis/oauth.openshift.io/v1/oauthclients/ztpfwoauth'

export type OAuthClientApiVersionType = 'oauth.openshift.io/v1';
export const OAuthClientApiVersion: OAuthClientApiVersionType = 'oauth.openshift.io/v1';

export type OAuthClientKindType = 'OAuthClient';
export const OAuthClientKind: OAuthClientKindType = 'OAuthClient';

export interface OAuthClient extends IResource {
  apiVersion: OAuthClientApiVersionType;
  kind: OAuthClientKindType;
  metadata: Metadata;
  redirectURIs?: string[];
  secret?: string;
}
