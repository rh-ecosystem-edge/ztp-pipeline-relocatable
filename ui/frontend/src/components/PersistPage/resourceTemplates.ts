import { Secret, SecretApiVersion, SecretKind } from '../../resources/secret';
import { Service, ServiceApiVersion, ServiceKind } from '../../resources/service';
import { ADDRESS_POOL_NAMESPACE, TLS_SECRET_NAMESPACE } from './constants';

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

export const HTPASSWD_SECRET: Secret = {
  apiVersion: SecretApiVersion,
  data: {
    htpasswd: '', // To be filled
  },
  kind: SecretKind,
  metadata: {
    generateName: 'ztpfw-htpasswd-secret-',
    namespace: 'openshift-config',
  },
  type: 'Opaque',
};

export const TLS_SECRET: Secret = {
  apiVersion: SecretApiVersion,
  data: {
    'tls.crt': '', // To be filled
    'tls.key': '', // To be filled
  },
  kind: SecretKind,
  metadata: {
    generateName: '', // To be filled
    name: 'api-secret',
    namespace: TLS_SECRET_NAMESPACE,
  },
  type: 'kubernetes.io/tls',
};

export const CLUSTER_ADMIN_ROLE_BINDING = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'ClusterRoleBinding',
  metadata: {
    generateName: 'cluster-admin-',
  },
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'cluster-admin',
  },
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'User',
      name: '', // To be filled
    },
  ],
};
