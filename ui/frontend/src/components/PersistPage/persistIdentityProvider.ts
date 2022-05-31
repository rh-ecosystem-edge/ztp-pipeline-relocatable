import { cloneDeep } from 'lodash';
import { createResource, patchResource, postRequest } from '../../resources';
import {
  getHtpasswdIdentityProvider,
  getOAuth,
  IndetityProviderType,
  OAuth,
} from '../../resources/oauth';
import { deleteSecret, getSecret } from '../../resources/secret';
import { IResource, Secret, PatchType } from '../../backend-shared';
import {
  IDENTITY_PROVIDER_NAME,
  kubeadminSecret,
  KUBEADMIN_REMOVE,
  PERSIST_IDP,
  RESOURCE_CREATE_TITLE,
  RESOURCE_FETCH_TITLE,
  RESOURCE_PATCH_TITLE,
} from './constants';
import { CLUSTER_ADMIN_ROLE_BINDING, HTPASSWD_SECRET } from './resourceTemplates';
import { PersistErrorType } from './types';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';

const getHtpasswdData = async (
  setError: (error: PersistErrorType) => void,
  username: string,
  password: string,
): Promise<string | undefined> => {
  try {
    const htPasswdData = (await postRequest('/htpasswd', {
      username,
      password,
    }).promise) as { htpasswdData: string };
    if (!htPasswdData?.htpasswdData) {
      console.error('Can not encode password to htpasswd');
      setError({
        title: RESOURCE_CREATE_TITLE,
        message: `Can not encode password for the ${HTPASSWD_SECRET.metadata.name} htpasswd secret in the ${HTPASSWD_SECRET.metadata.name} namespace.`,
      });
      return undefined;
    }
    const htPasswdDataB64 = btoa(htPasswdData.htpasswdData);
    return htPasswdDataB64;
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_IDP,
      message: 'Failed to add new OAuth identity provider.',
    });
  }

  return undefined;
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

export enum PersistIdentityProviderResult {
  error = 'error',
  skipped = 'skipped',
  userCreated = 'userCreated',
}

export const persistIdentityProvider = async (
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  username: string,
  password: string,
): Promise<PersistIdentityProviderResult> => {
  if (!username || !password) {
    console.log('persistIdentityProvider: username or password missing, so skipping that step.');
    setProgress(PersistSteps.PersistIDP);
    return PersistIdentityProviderResult.skipped;
  }

  let oauth;
  try {
    // cluster-scoped, name: cluster
    oauth = await getOAuth().promise;
  } catch (e) {
    console.error(e);
    setError({ title: RESOURCE_FETCH_TITLE, message: 'Failed to get the OAuth resource.' });
    return PersistIdentityProviderResult.error;
  }

  const htpasswdIdentityProvider = getHtpasswdIdentityProvider(oauth);

  if (htpasswdIdentityProvider) {
    console.info(
      `The ${IDENTITY_PROVIDER_NAME} is already present, skipping. To edit username/password, change the htpasswd secret resource.`,
    );

    // skip username/passwod wizard steps for that case
    setProgress(PersistSteps.PersistIDP);
    return PersistIdentityProviderResult.skipped;
  }

  // encode password
  const htPasswdDataB64 = await getHtpasswdData(setError, username, password);
  if (!htPasswdDataB64) {
    return PersistIdentityProviderResult.error;
  }

  // create HTPasswd Secret
  const secret = await createSecret(setError, htPasswdDataB64);
  if (!secret) {
    return PersistIdentityProviderResult.error;
  }

  // Patch (add) new IDP record
  if (!(await patchIDP(setError, oauth, secret))) {
    return PersistIdentityProviderResult.error;
  }

  // grant cluster-admin privileges
  if (!(await bindClusterAdminRole(setError, username))) {
    return PersistIdentityProviderResult.error;
  }

  setProgress(PersistSteps.PersistIDP);
  return PersistIdentityProviderResult.userCreated;
};

export const deleteKubeAdmin = async (
  setError: (error: PersistErrorType) => void,
): Promise<boolean> => {
  let secret;
  try {
    // The 404 is a valid state in this flow
    secret = await getSecret(kubeadminSecret).promise;

    // Ok, it is still there, so remove it
    await deleteSecret(kubeadminSecret).promise;
  } catch (e) {
    if (secret) {
      // It is not a failure if the secret is already missing
      console.error(e);
      setError({ title: KUBEADMIN_REMOVE, message: 'Failed to remove the kubeadmin user.' });
      return false;
    }
  }

  return true;
};
