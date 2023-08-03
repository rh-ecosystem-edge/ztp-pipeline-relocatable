import { getHtpasswdIdentityProvider, getOAuth, OAuth } from '../../resources/oauth';
import { workaroundUnmarshallObject } from '../../test-utils';
import { setUIErrorType } from '../types';

type LoadCredentialsReturnType = { isAdminCreated: boolean };

export const loadCredentials = async ({
  setError,
}: {
  setError: setUIErrorType;
}): Promise<LoadCredentialsReturnType> => {
  let oauth: OAuth | undefined;

  try {
    oauth = await getOAuth().promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };

    if (e.code === 404) {
      setError({
        title: `Can not find cluster OAuth resource.`,
        message: 'The cluster is not properly deployed.',
      });
      return {
        isAdminCreated: false,
      };
    }

    if (e.code === 401) {
      setError({
        title: 'Unauthorized',
        message: 'Redirecting to login page.',
      });
      return {
        isAdminCreated: false,
      };
    }

    if (e.code !== 404) {
      console.error(e, e.code);
      setError({ title: 'Failed to contact OpenShift Platform API.', message: e.message });
      return {
        isAdminCreated: false,
      };
    }
  }

  // workarounds for tests
  oauth = workaroundUnmarshallObject(oauth);

  if (getHtpasswdIdentityProvider(oauth)) {
    // TODO: Parse HTPasswd data in the secret in case we need UPDATE feature on the creadentials
    return {
      isAdminCreated: true,
    };
  }

  return {
    isAdminCreated: false,
  };
};
