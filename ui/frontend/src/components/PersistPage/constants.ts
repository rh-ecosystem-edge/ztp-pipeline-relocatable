export const RESOURCE_CREATE_TITLE = 'Resource create failed';
export const RESOURCE_PATCH_TITLE = 'Resource update failed';
export const MISSING_VALUE = 'Missing value';
export const RESOURCE_FETCH_TITLE = 'Failed to read resource';
export const PERSIST_IDP = 'Registering new identity HTPasswd provider failed.';

export const IDENTITY_PROVIDER_NAME = 'ztpfw-htpasswd-idp';

export const DELAY_BEFORE_FINAL_REDIRECT = 2 * 1000;

export const SSH_PRIVATE_KEY_SECRET = {
  name: 'cluster-ssh-keypair',
  namespace: 'default' /* !?! */,
};
export const SSH_PRIVATE_KEY_SECRET_TITLE = 'Missing SSH private key';
export const SSH_PRIVATE_KEY_SECRET_INCORRECT = 'Incorrect SSH key secret';
