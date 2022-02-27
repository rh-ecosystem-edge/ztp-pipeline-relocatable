import { Metadata } from './metadata';
import { IResource } from './resource';

export interface Route extends IResource {
  apiVersion: 'route.openshift.io/v1';
  kind: 'Route';
  metadata: Metadata;
  spec?: {
    host?: string;
  };
}
