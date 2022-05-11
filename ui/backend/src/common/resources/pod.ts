import { Metadata } from './metadata';
import { IResource } from './resource';
import { StatusCondition } from './statuscondition';

export type PodApiVersionType = 'v1';
export const PodApiVersion: PodApiVersionType = 'v1';

export type PodKindType = 'Pod';
export const PodKind: PodKindType = 'Pod';

export interface Pod extends IResource {
  apiVersion: PodApiVersionType;
  kind: PodKindType;
  metadata: Metadata;
  spec?: {
    containers?: {
      env?: {
        name: string;
        value: string;
      }[];
    }[];
  };
  status?: {
    conditions: StatusCondition[];
  };
}
