import { cloneDeep } from 'lodash';
import { createResource, patchResource, postRequest } from '../../resources';
import { getOAuth, IndetityProviderType, OAuth } from '../../resources/oauth';
import { PatchType } from '../../resources/patches';
import { IResource } from '../../resources/resource';
import { Secret } from '../../resources/secret';
import {
  IDENTITY_PROVIDER_NAME,
  PERSIST_IDP,
  RESOURCE_CREATE_TITLE,
  RESOURCE_FETCH_TITLE,
  RESOURCE_PATCH_TITLE,
} from './constants';
import { CLUSTER_ADMIN_ROLE_BINDING, HTPASSWD_SECRET } from './resourceTemplates';
import { PersistErrorType } from './types';

const getHtpasswdData = async (
  setError: (error: PersistErrorType) => void,
  username: string,
  password: string,
): Promise<string | undefined> => {
  let htPasswdDataB64: string | undefined = undefined;
  try {
    const htPasswdData = await postRequest('/htpasswd', {
      username,
      password,
    }).promise;
    // htPasswdDataB64 = Buffer.from(htPasswdData as string).toString('base64');
    htPasswdDataB64 = btoa(htPasswdData as string);
    if (!htPasswdDataB64) {
      console.error('Can not encode password to htpasswd');
      setError({
        title: RESOURCE_CREATE_TITLE,
        message: `Can not encode password for the ${HTPASSWD_SECRET.metadata.name} htpasswd secret in the ${HTPASSWD_SECRET.metadata.name} namespace.`,
      });
    }
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_IDP,
      message: 'Failed to add new OAuth identity provider.',
    });
  }

  return htPasswdDataB64;
};

const createSecret = async (
  setError: (error: PersistErrorType) => void,
  htPasswdDataB64: string,
): Promise<Secret | undefined> => {
  try {
    const object = cloneDeep(HTPASSWD_SECRET);
    object.data && (object.data.htpasswd = htPasswdDataB64);

    return createResource(object).promise;
  } catch (e) {
    console.error('Can not create resource: ', e);
    setError({
      title: RESOURCE_CREATE_TITLE,
      message: `Can not create ${HTPASSWD_SECRET.metadata.generateName} htpasswd secret in the ${HTPASSWD_SECRET.metadata.namespace} namespace.`,
    });
  }
  return undefined;
};

const patchIDP = async (
  setError: (error: PersistErrorType) => void,
  oauth: OAuth,
  secret: Secret,
): Promise<OAuth | undefined> => {
  const identityProviders: IndetityProviderType[] = oauth.spec?.identityProviders || [];
  identityProviders.push({
    name: IDENTITY_PROVIDER_NAME,
    mappingMethod: 'claim',
    type: 'HTPasswd',
    htpasswd: {
      fileData: {
        name: secret.metadata.name || '',
      },
    },
  });
  const patches: PatchType[] = [
    {
      op: oauth.spec?.identityProviders === undefined ? 'add' : 'replace',
      path: '/spec/identityProviders',
      value: identityProviders,
    },
  ];

  try {
    const response = await patchResource(oauth, patches).promise;
    console.log(`Patched OAuth resource for new htpasswd provider:`, response);
    return response;
  } catch (e) {
    console.error('Can not patch resource: ', e, oauth, patches);
    setError({
      title: RESOURCE_PATCH_TITLE,
      message: `Can not update OAuth resource for new htpasswd identity provider.`,
    });
  }
  return undefined;
};

// Mimics: oc adm policy add-cluster-role-to-user cluster-admin [USER]
const bindClusterAdminRole = async (
  setError: (error: PersistErrorType) => void,
  username: string,
): Promise<IResource | undefined> => {
  try {
    const object = cloneDeep(CLUSTER_ADMIN_ROLE_BINDING);
    object.subjects[0].name = username;

    return createResource(object).promise;
  } catch (e) {
    console.error('Can not create resource: ', e);
    setError({
      title: RESOURCE_CREATE_TITLE,
      message: `Can not create ${CLUSTER_ADMIN_ROLE_BINDING.metadata.generateName} ClusterRoleBinding resource to grant cluster-admin role to the ${username} user.`,
    });
  }
  return undefined;
};

export const persistIdentityProvider = async (
  setError: (error: PersistErrorType) => void,
  username: string,
  password: string,
): Promise<boolean> => {
  if (!username || !password) {
    console.log('persistIdentityProvider: username or password missing, so skipping that step.');
    return true; // skip
  }

  let oauth;
  try {
    // cluster-scoped, name: cluster
    oauth = await getOAuth().promise;
  } catch (e) {
    console.error(e);
    setError({ title: RESOURCE_FETCH_TITLE, message: 'Failed to get the OAuth resource.' });
    return false;
  }

  const htpasswdIdentityProvider = oauth.spec?.identityProviders?.find(
    (ip) => ip.name === IDENTITY_PROVIDER_NAME,
  );

  if (htpasswdIdentityProvider) {
    console.info(
      `The ${IDENTITY_PROVIDER_NAME} is already present, skipping. To edit username/password, change the htpasswd secret resource.`,
    );

    // skip username/passwod wizard steps for that case
    return true;
  }

  // encode password
  const htPasswdDataB64 = await getHtpasswdData(setError, username, password);
  if (!htPasswdDataB64) {
    return false;
  }

  // create HTPasswd Secret
  const secret = await createSecret(setError, htPasswdDataB64);
  if (!secret) {
    return false;
  }

  // Patch (add) new IDP record
  if (!(await patchIDP(setError, oauth, secret))) {
    return false;
  }

  // grant cluster-admin privileges
  if (!(await bindClusterAdminRole(setError, username))) {
    return false;
  }

  return true;
};
