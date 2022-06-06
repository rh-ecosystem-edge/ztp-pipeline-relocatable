import { getService } from '../../resources/service';
import { K8SStateContextData } from '../types';
import {
  SERVICE_TEMPLATE_API,
  SERVICE_TEMPLATE_METALLB_INGRESS,
} from '../PersistPage/resourceTemplates';
import { ipWithoutDots } from '../utils';
import { getHtpasswdIdentityProvider, getOAuth } from '../../resources/oauth';
import { workaroundUnmarshallObject } from '../../test-utils';
import { getIngressConfig } from '../../resources/ingress';
import {
  getClusterDomainFromComponentRoutes,
  Ingress,
  NodeNetworkState,
  NodeNetworkConfigurationPolicy,
  Node,
  HostType,
  HostInterfaceType,
} from '../../copy-backend-common';
import { getNodeNetworkStates } from '../../resources/NodeNetworkState';
import { getNodeNetworkConfigurationPolicies } from '../../resources/NodeNetworkConfigurationPolicy';
import { getNodes } from '../../resources/node';

const loadStaticIPs = async (
  handleSetHost: K8SStateContextData['handleSetHost'],
  nodes: Node[] = [],
  nodeNetworkStates: NodeNetworkState[] = [],
  nodeNetworkConfigurationPolicies: NodeNetworkConfigurationPolicy[] = [],
) => {
  // query list of nodes
  // query nodenetworkstates (owenerReference)
  // query NodeNetworkConfigurationPolicy (spec.nodeSelector[kubernetes.io/hostname] === ztpfw-edgecluster0-cluster-master-0 )

  nodes?.forEach((node) => {
    const nodeName = node.metadata.name || 'typescript-workaround-nodename';
    const nns: NodeNetworkState | undefined = nodeNetworkStates.find(
      (o) => o.metadata.ownerReferences?.find((or) => or.kind === 'Node')?.name === nodeName,
    );
    const nncp: NodeNetworkConfigurationPolicy | undefined = nodeNetworkConfigurationPolicies.find(
      (o) =>
        o.spec?.nodeSelector?.['kubernetes.io/hostname'] ===
        nodeName /* TODO: verify that this is really nodeName and not node's hostname */,
    );

    if (!nns) {
      // AssumptionL there is 1:1 pairing
      console.error('A NodeNetworkState is not associated to a Node: ', nns);
      return;
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

    handleSetHost(host);
  });
};

export const initialDataLoad = async ({
  setNextPage,
  setError,
  handleSetApiaddr,
  handleSetIngressIp,
  handleSetDomain,
  setClean,
  handleSetHost,
}: {
  setNextPage: (href: string) => void;
  setError: (message?: string) => void;
  handleSetApiaddr: K8SStateContextData['handleSetApiaddr'];
  handleSetIngressIp: K8SStateContextData['handleSetIngressIp'];
  handleSetDomain: K8SStateContextData['handleSetDomain'];
  setClean: K8SStateContextData['setClean'];
  handleSetHost: K8SStateContextData['handleSetHost'];
}) => {
  console.log('Initial data load');

  let ingressService, apiService, oauth;
  let ingressConfig: Ingress | undefined;
  let nodeNetworkStates: NodeNetworkState[] | undefined;
  let nodeNetworkConfigurationPolicies: NodeNetworkConfigurationPolicy[] | undefined;
  let nodes: Node[] | undefined;

  try {
    oauth = await getOAuth().promise;
    ingressService = await getService({
      name: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.name || '',
      namespace: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.namespace || '',
    }).promise;
    apiService = await getService({
      name: SERVICE_TEMPLATE_API.metadata.name || '',
      namespace: SERVICE_TEMPLATE_API.metadata.namespace || '',
    }).promise;
    ingressConfig = await getIngressConfig().promise;
    nodeNetworkStates = await getNodeNetworkStates().promise;
    nodeNetworkConfigurationPolicies = await getNodeNetworkConfigurationPolicies().promise;
    nodes = await getNodes().promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };
    if (e.code !== 404) {
      console.error(e, e.code);
      setError('Failed to contact OpenShift Platform API.');
      return;
    }
  }

  // workarounds for tests
  oauth = workaroundUnmarshallObject(oauth);
  ingressService = workaroundUnmarshallObject(ingressService);
  apiService = workaroundUnmarshallObject(apiService);
  ingressConfig = workaroundUnmarshallObject(ingressConfig);
  nodeNetworkStates = workaroundUnmarshallObject(nodeNetworkStates);
  nodeNetworkConfigurationPolicies = workaroundUnmarshallObject(nodeNetworkConfigurationPolicies);
  nodes = workaroundUnmarshallObject(nodes);

  handleSetIngressIp(
    ipWithoutDots(
      ingressService?.spec?.loadBalancerIP ||
        ingressService?.status?.loadBalancer?.ingress?.[0]?.ip,
    ),
  );
  handleSetApiaddr(
    ipWithoutDots(
      apiService?.spec?.loadBalancerIP || apiService?.status?.loadBalancer?.ingress?.[0]?.ip,
    ),
  );

  const currentHostname = getClusterDomainFromComponentRoutes(ingressConfig);
  if (currentHostname) {
    handleSetDomain(currentHostname);
  }

  await loadStaticIPs(handleSetHost, nodes, nodeNetworkStates, nodeNetworkConfigurationPolicies);

  setClean();

  if (getHtpasswdIdentityProvider(oauth)) {
    // DO NOT MERGE FOLLOWING LINE!!!
    setNextPage('/wizard/staticips');

    // The Edit flow for the 2nd and later run
    // setNextPage('/settings');
  } else {
    // The Wizard for the very first run
    setNextPage('/wizard/username');
  }
};
