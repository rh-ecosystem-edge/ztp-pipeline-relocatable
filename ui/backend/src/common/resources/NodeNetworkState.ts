import { Metadata } from './metadata';
import { IResource } from './resource';

export type NodeNetworkStateType = 'nmstate.io/v1beta1';
export const NodeNetworkStateApiVersion: NodeNetworkStateType = 'nmstate.io/v1beta1';

export type NodeNetworkStateKindType = 'NodeNetworkState';
export const NodeNetworkStateKind: NodeNetworkStateKindType = 'NodeNetworkState';

interface NodeNetworkStateInterface {
  ipv4: {
    address: {
      ip: string;
      'prefix-length': number;
    }[];
    enabled: false;
  };
  // ipv6: {}
  type: 'ethernet' | 'anything-else-is-not-important-now';
  name: string;
  state: 'down' | 'up';
  mtu: number;
  'mac-address': string;
  dhcp: boolean;
  enabled: boolean;
  'auto-dns': boolean;
  'auto-gateway': boolean;
}

export interface NNRouteConfig {
  destination: string; // subnet mask
  metric: number;
  'next-hop-address': string; // gateway
  'next-hop-interface': string; // interface name
}

export interface NodeNetworkState extends IResource {
  apiVersion: NodeNetworkStateType;
  kind: NodeNetworkStateKindType;
  metadata: Metadata;

  status?: {
    currentState?: {
      'dns-resolver'?: {
        running?: {
          server?: string[];
        };
      };
      interfaces?: NodeNetworkStateInterface[];
      routes?: {
        running?: NNRouteConfig[];
      };
    };
  };
}
