import { Service } from '../../copy-backend-common';
import { getService } from '../../resources/service';
import { workaroundUnmarshallObject } from '../../test-utils';
import { setUIErrorType } from '../types';
import { ipWithoutDots } from '../utils';
import { SERVICE_TEMPLATE_METALLB_INGRESS } from './template';

export const loadIngressData = async ({
  setError,
}: {
  setError: setUIErrorType;
}): Promise<string | undefined> => {
  let ingressService: Service | undefined;

  try {
    ingressService = await getService({
      name: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.name || '',
      namespace: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.namespace || '',
    }).promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };

    if (e.code === 404) {
      setError({
        title: `Can not find ${SERVICE_TEMPLATE_METALLB_INGRESS.metadata.name} service.`,
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
  ingressService = workaroundUnmarshallObject(ingressService);

  const ingressVip = ipWithoutDots(
    ingressService?.spec?.loadBalancerIP || ingressService?.status?.loadBalancer?.ingress?.[0]?.ip,
  );

  return ingressVip;
};
