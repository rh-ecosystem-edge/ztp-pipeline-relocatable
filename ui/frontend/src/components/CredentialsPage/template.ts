import { Secret, SecretApiVersion, SecretKind } from '../../copy-backend-common';

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
