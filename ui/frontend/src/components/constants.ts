export const EMPTY_VIP = '            '; // 12 characters

export const ADDRESS_POOL_ANNOTATION_KEY = 'metallb.universe.tf/address-pool';
export const ADDRESS_POOL_NAMESPACE = 'metallb';

export const DELAY_BEFORE_RECONCILIATION = 10 * 1000;
export const DELAY_BEFORE_QUERY_RETRY = 5 * 1000; /* ms */
export const CLUSTER_OPERATOR_POLLING_INTERVAL = DELAY_BEFORE_QUERY_RETRY;
export const MAX_LIVENESS_CHECK_COUNT = 20 * ((60 * 1000) / DELAY_BEFORE_QUERY_RETRY); // max 20 minutes

export const KubeadminSecret = { name: 'kubeadmin', namespace: 'kube-system' };
export const SSH_PRIVATE_KEY_SECRET = {
  name: 'cluster-ssh-keypair',
  namespace: 'default' /* !?! */,
};

export const MONITORED_CLUSTER_OPERATORS = [
  'kube-apiserver',
  'openshift-apiserver',
  'authentication',
];
