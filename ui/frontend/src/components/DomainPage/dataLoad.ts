import { getClusterDomainFromComponentRoutes, Ingress, Service } from '../../copy-backend-common';
import { getIngressConfig } from '../../resources/ingress';
import { workaroundUnmarshallObject } from '../../test-utils';
import { setUIErrorType } from '../types';

export const loadDomainData = async ({
  setError,
}: {
  setError: setUIErrorType;
}): Promise<string | undefined> => {
  let ingressConfig: Ingress | undefined;

  try {
    ingressConfig = await getIngressConfig().promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };

    if (e.code === 404) {
      setError({
        title: `Can not find Ingress resource`,
        message: 'The cluster is not properly deployed.',
      });
      return;
    }

    if (e.code === 401) {
      setError({
        title: 'Unauthorized',
        message: 'Redirecting to login page.',
      });
      return;
    }

    if (e.code !== 404) {
      console.error(e, e.code);
      setError({ title: 'Failed to contact OpenShift Platform API.', message: e.message });
      return;
    }
  }

  // workarounds for tests
  ingressConfig = workaroundUnmarshallObject(ingressConfig);

  return getClusterDomainFromComponentRoutes(ingressConfig);
};
