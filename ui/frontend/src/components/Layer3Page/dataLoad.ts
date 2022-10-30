import {
  HostType,
  HostInterfaceType,
  OwnerReference,
  NodeNetworkState,
  Node,
  NodeNetworkConfigurationPolicy,
} from '../../copy-backend-common';
import { getAllNodes } from '../../resources/node';
import { getAllNodeNetworkConfigurationPolicies } from '../../resources/nodeNetworkConfigurationPolicies';
import { getAllNodeNetworkStates } from '../../resources/nodeNetworkStates';
import { setUIErrorType } from '../types';

export const loadStaticIPs = async (setError: setUIErrorType): Promise<HostType[]> => {
  let allNodes: Node[] = [];
  let allNodeNetworkStates: NodeNetworkState[];
  let allNodeNetworkConfigurationPolicies: NodeNetworkConfigurationPolicy[];

  try {
    allNodes = await getAllNodes().promise;
    allNodeNetworkStates = await getAllNodeNetworkStates().promise;
    allNodeNetworkConfigurationPolicies = await getAllNodeNetworkConfigurationPolicies().promise;
  } catch (e) {
    console.error('loadStaticIPs error: ', e);
    setError({ title: 'Failed to load static IPs' });
  }

  const result: (HostType | undefined)[] = allNodes.map((node): HostType | undefined => {
    const nodeName = node.metadata.name as string;
    const nns: NodeNetworkState | undefined = allNodeNetworkStates?.find(
      (o) =>
        o.metadata.ownerReferences?.find((or: OwnerReference) => or.kind === 'Node')?.name ===
        nodeName,
    );
    const nncp: NodeNetworkConfigurationPolicy | undefined =
      allNodeNetworkConfigurationPolicies?.find(
        (o) =>
          o.spec?.nodeSelector?.['kubernetes.io/hostname'] ===
          nodeName /* TODO: verify that this is really nodeName and not node's hostname */,
      );

    if (!nns) {
      // Assumption: there is 1:1 pairing
      console.error('A NodeNetworkState is not associated to a Node so skipping the Node: ', nns);

      const fakeHost: HostType = {
        nodeName,
        hostname: `${nodeName}-fakehostname`,
        nncpName: `${nodeName}-fakeNNCPName`,
        role: 'control',
        interfaces: [
          {
            name: `fakeInterface0`,
            ipv4: {
              address: {
                // We support only one static IP per interface
                ip: '2.2.2.2',
                prefixLength: 24,
                gateway: '3.3.3.3',
              },
            },
          },
        ],
        // -- gateway, // single IP address
        dns: ['1.1.1.1', '2.2.2.2'], // list of IP addresses
      };
      return fakeHost; // TODO: do not do that

      // TODO use this: return;
    }

    const hostname =
      node.status?.addresses?.find((a) => a.type === 'Hostname')?.address || nodeName;

    // The node can act as both worker and master at the same time. For our purpose so far, we can be exclusive. Change otherwise.
    const role =
      node.metadata.labels?.['node-role.kubernetes.io/master'] !== undefined ? 'control' : 'worker';

    const dns =
      nncp?.spec?.desiredState?.['dns-resolver']?.config?.server ||
      nns.status?.currentState?.['dns-resolver']?.running?.server ||
      [];

    const host: HostType = {
      nodeName,
      hostname,
      nncpName: nncp?.metadata.name,
      role,
      interfaces: [],
      // -- gateway, // single IP address
      dns, // list of IP addresses
    };

    // Take the list of interfaces from actual status (NodeNetworkStatus)
    const intfs = nns.status?.currentState?.interfaces?.filter(
      (intf) => intf.type === 'ethernet' && intf.state === 'up',
    );

    intfs?.forEach((intf) => {
      const nncpIntf = nncp?.spec?.desiredState?.interfaces?.find((o) => o.name === intf.name);

      const nncpIntfRoutes = nncp?.spec?.desiredState?.routes?.config
        ?.filter((r) => r['next-hop-interface'] === intf.name)
        ?.sort((r1, r2) => r2.metric - r1.metric /* descending */);
      const nnsIntfRoutes = nns?.status?.currentState?.routes?.running
        ?.filter((r) => r['next-hop-interface'] === intf.name)
        ?.sort((r1, r2) => r2.metric - r1.metric /* descending */);
      const gateway =
        nncpIntfRoutes?.[0]['next-hop-address'] || nnsIntfRoutes?.[0]['next-hop-address'] || '';

      const hostInterface: HostInterfaceType = {
        name: intf.name,
        ipv4: {
          /* To be filled bellow */
        },
      };

      const ipv4Address = nncpIntf?.ipv4?.address?.[0] || intf?.ipv4?.address?.[0]; // Take the first-one only

      if (ipv4Address) {
        hostInterface.ipv4.address = {
          // We support only one static IP per interface
          ip: ipv4Address.ip,
          prefixLength: ipv4Address['prefix-length'],
          gateway,
        };
      }

      host.interfaces.push(hostInterface);
    });

    return host;
  });

  const sortedHosts = (result.filter(Boolean) as HostType[]).sort((h1, h2) => {
    // First by role, control plane nodes first
    if (h1.role !== h2.role) {
      if (h1.role === 'control') {
        return -1;
      }
      return 1;
    }

    // Then by hostname
    return (h1.hostname || h1.nodeName).localeCompare(h2.hostname || h2.nodeName);
  });

  return sortedHosts;
};
