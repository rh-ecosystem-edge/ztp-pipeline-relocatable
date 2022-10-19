import { Service } from '../../copy-backend-common';
import { getService } from '../../resources/service';
import { workaroundUnmarshallObject } from '../../test-utils';
import { setUIErrorType } from '../types';
import { ipWithoutDots } from '../utils';
import { SERVICE_TEMPLATE_API } from './template';

export const loadApiData = async ({
  setError,
}: {
  setError: setUIErrorType;
}): Promise<string | undefined> => {
  let apiService: Service | undefined;

  try {
    apiService = await getService({
      name: SERVICE_TEMPLATE_API.metadata.name || '',
      namespace: SERVICE_TEMPLATE_API.metadata.namespace || '',
    }).promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };

    if (e.code === 404) {
      setError({
        title: `Can not find ${SERVICE_TEMPLATE_API.metadata.name} service.`,
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
  apiService = workaroundUnmarshallObject(apiService);

  const apiVip = ipWithoutDots(
    apiService?.spec?.loadBalancerIP || apiService?.status?.loadBalancer?.ingress?.[0]?.ip,
  );

  return apiVip;
};
