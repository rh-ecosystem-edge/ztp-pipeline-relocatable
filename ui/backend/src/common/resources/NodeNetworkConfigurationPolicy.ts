import { Metadata } from './metadata';
import { NNRouteConfig } from './NodeNetworkState';
import { IResource } from './resource';

export type NodeNetworkConfigurationPolicyType = 'nmstate.io/v1';
export const NodeNetworkConfigurationPolicyApiVersion: NodeNetworkConfigurationPolicyType =
  'nmstate.io/v1';

export type NodeNetworkConfigurationPolicyKindType = 'NodeNetworkConfigurationPolicy';
export const NodeNetworkConfigurationPolicyKind: NodeNetworkConfigurationPolicyKindType =
  'NodeNetworkConfigurationPolicy';

export type NNCPInterface = {
  name: string;
  state: 'up' | 'down';
  type?: 'ethernet';
  ipv4: {
    address: {
      ip: string;
      'prefix-length': number;
    }[];
    enabled: boolean;
  };
};
export interface NodeNetworkConfigurationPolicy extends IResource {
  apiVersion: NodeNetworkConfigurationPolicyType;
  kind: NodeNetworkConfigurationPolicyKindType;
  metadata: Metadata;

  spec: {
    nodeSelector?: {
      // kubernetes.io/hostname: ztpfw-edgecluster0-cluster-master-0
      [key: string]: string;
    };
    desiredState: {
      interfaces: NNCPInterface[];

      'dns-resolver'?: {
        // TODO: don't forget to set ipv4[auto-dns] to false
        config: {
          server: string[];
        };
      };

      routes?: {
        config?: NNRouteConfig[];
      };
    };
  };
}
