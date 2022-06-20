import { ZTPFW_UI_ROUTE_PREFIX } from '../../copy-backend-common';
import { getRequest } from '../../resources';
import { getPodsOfNamespace } from '../../resources/pod';
import { delay, getZtpfwUrl } from '../utils';
import {
  DELAY_BEFORE_FINAL_REDIRECT,
  MAX_LIVENESS_CHECK_COUNT,
  ZTPFW_NAMESPACE,
} from './constants';

export const waitForLivenessProbe = async (
  counter = MAX_LIVENESS_CHECK_COUNT,
  ztpfwUrl?: string,
) => {
  // This works thanks to the route backup
  ztpfwUrl = ztpfwUrl || getZtpfwUrl();

  try {
    // We can not check new domain for availability due to CORS
    await delay(DELAY_BEFORE_FINAL_REDIRECT);
    console.info('Checking livenessProbe');
    await getRequest(`${ztpfwUrl}/livenessProbe`).promise;

    return true;
  } catch (e) {
    console.info('ZTPFW UI is not yet ready: ', e);
    if (counter > 0) {
      await waitForLivenessProbe(counter - 1, ztpfwUrl);
    } else {
      console.error('ZTPFW UI did not turn ready, giving up');
      return false;
    }
  }
};

export const waitForZtpfwPodToBeRecreated = async (
  counter = MAX_LIVENESS_CHECK_COUNT,
  newDomain: string,
): Promise<boolean> => {
  console.log('Waiting for ZTPFW UI pod to be ready');
  await delay(DELAY_BEFORE_FINAL_REDIRECT);

  try {
    const pods = await getPodsOfNamespace(ZTPFW_NAMESPACE).promise;

    const readyPods = pods.filter((p) =>
      p.status?.conditions?.find((c) => c.type === 'Ready' && c.status === 'True'),
    );

    const isNewPodReady = !!readyPods.find(
      (p) =>
        !!p.spec?.containers?.find(
          (c) =>
            !!c.env?.find(
              (e) =>
                e.name === 'FRONTEND_URL' &&
                e.value === `https://${ZTPFW_UI_ROUTE_PREFIX}.apps.${newDomain}`,
            ),
        ),
    );

    if (isNewPodReady) {
      return true;
    }

    if (counter > 0) {
      return await waitForZtpfwPodToBeRecreated(counter - 1, newDomain);
    }
  } catch (e) {
    console.error('Failed to query ZTPFW pods: ', e);
  }
  return false;
};
