import { Service, ServiceApiVersion, ServiceKind } from '../../copy-backend-common';
import { ADDRESS_POOL_NAMESPACE } from '../constants';

export const SERVICE_TEMPLATE_METALLB_INGRESS: Service = {
  kind: ServiceKind,
  apiVersion: ServiceApiVersion,
  metadata: {
    annotations: {
      // To be filled: 'metallb.universe.tf/address-pool': 'ztpfw-ingress-public-ip',
    },
    name: 'metallb-ingress',
    namespace: 'openshift-ingress',
  },
  spec: {
    loadBalancerIP: '', // To be filled
    ports: [
      { name: 'http', protocol: 'TCP', port: 80, targetPort: 80 },
      { name: 'https', protocol: 'TCP', port: 443, targetPort: 443 },
    ],
    selector: {
      'ingresscontroller.operator.openshift.io/deployment-ingresscontroller': 'default',
    },
    type: 'LoadBalancer',
  },
};

export const ADDRESS_POOL_TEMPLATE = {
  apiVersion: 'metallb.io/v1alpha1',
  kind: 'AddressPool',
  metadata: {
    generateName: 'ztpfw-', // To be filled
    name: '',
    namespace: ADDRESS_POOL_NAMESPACE,
  },
  spec: {
    protocol: 'layer2',
    addresses: [
      '', // To be filled, example: '172.18.0.100-172.18.0.255',
    ],
  },
};
