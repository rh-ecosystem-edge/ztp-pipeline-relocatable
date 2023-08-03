import { Service, ServiceApiVersion, ServiceKind } from '../../copy-backend-common';

export const SERVICE_TEMPLATE_API: Service = {
  kind: ServiceKind,
  apiVersion: ServiceApiVersion,
  metadata: {
    annotations: {
      // To be filled, 'metallb.universe.tf/address-pool': 'ztpfw-api-public-ip',
    },
    name: 'metallb-api',
    namespace: 'openshift-kube-apiserver',
  },
  spec: {
    loadBalancerIP: '', // To be filled
    ports: [{ name: 'http', protocol: 'TCP', port: 6443, targetPort: 6443 }],
    selector: {
      app: 'openshift-kube-apiserver',
    },
    type: 'LoadBalancer',
  },
};
