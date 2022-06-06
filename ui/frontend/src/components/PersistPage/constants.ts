export const RESOURCE_CREATE_TITLE = 'Resource create failed';
export const RESOURCE_PATCH_TITLE = 'Resource update failed';
export const MISSING_VALUE = 'Missing value';
export const RESOURCE_FETCH_TITLE = 'Failed to read resource';
export const PERSIST_IDP = 'Registering new identity HTPasswd provider failed.';
export const KUBEADMIN_REMOVE = 'Kubeadmin removal failed.';
export const KUBEADMIN_REMOVE_OK = 'Kubeadmin removed.';
export const PERSIST_STATIC_IPS = 'Changing static IP setting failed.';
export const PERSIST_DOMAIN = 'Changing domain failed.';
export const UI_POD_NOT_READY = 'Configuration UI pod is not ready';
export const API_LIVENESS_FAILED_TITLE = 'API can not be reached';
export const WAIT_ON_OPERATOR_TITLE = 'Reading operator status failed';

export const IDENTITY_PROVIDER_NAME = 'ztpfw-htpasswd-idp';
export const ZTPFW_NAMESPACE = 'ztpfw-ui';

export const DELAY_BEFORE_FINAL_REDIRECT = 10 * 1000;
export const DELAY_BEFORE_QUERY_RETRY = 5 * 1000; /* ms */
export const MAX_LIVENESS_CHECK_COUNT = 20 * ((60 * 1000) / DELAY_BEFORE_QUERY_RETRY); // max 20 minutes

export const SSH_PRIVATE_KEY_SECRET = {
  name: 'cluster-ssh-keypair',
  namespace: 'default' /* !?! */,
};
export const SSH_PRIVATE_KEY_SECRET_TITLE = 'Missing SSH private key';
export const SSH_PRIVATE_KEY_SECRET_INCORRECT = 'Incorrect SSH key secret';

export const ADDRESS_POOL_ANNOTATION_KEY = 'metallb.universe.tf/address-pool';
export const ADDRESS_POOL_NAMESPACE = 'metallb';

export const kubeadminSecret = { name: 'kubeadmin', namespace: 'kube-system' };
