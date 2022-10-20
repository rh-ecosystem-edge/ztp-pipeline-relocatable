import { Service, ServiceApiVersion, ServiceKind } from '../../copy-backend-common';

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
