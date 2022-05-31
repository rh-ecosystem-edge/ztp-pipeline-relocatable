import { Metadata } from './metadata';
import { IResource } from './resource';

// /apis/apps/v1/namespaces/ztpfw-ui/deployments/ztpfw-ui'

export type DeploymentApiVersionType = 'apps/v1';
export const DeploymentApiVersion: DeploymentApiVersionType = 'apps/v1';

export type DeploymentKindType = 'Deployment';
export const DeploymentKind: DeploymentKindType = 'Deployment';

export interface Deployment extends IResource {
  apiVersion: DeploymentApiVersionType;
  kind: DeploymentKindType;
  metadata: Metadata;
  spec?: {
    template?: {
      spec?: {
        containers?: {
          env: {
            name: string;
            value: string;
          }[];
          image: string;
          volumes: {
            name: string;
            secret?: {
              secretName: string;
            };
          }[];
        }[];
      };
    };
  };
}
