import { Service, ServiceApiVersion, ServiceKind } from '../../resources/service';

export const SERVICE_TEMPLATE_METALLB_INGRESS: Service = {
  kind: ServiceKind,
  apiVersion: ServiceApiVersion,
  metadata: {
    annotations: {
      'metallb.universe.tf/address-pool': 'ingress-public-ip',
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

export const SERVICE_TEMPLATE_API: Service = {
  kind: ServiceKind,
  apiVersion: ServiceApiVersion,
  metadata: {
    annotations: {
      'metallb.universe.tf/address-pool': 'api-public-ip',
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
