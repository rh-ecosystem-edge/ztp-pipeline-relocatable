import { getCondition, ZTPFW_UI_ROUTE_PREFIX } from '../../copy-backend-common';
import { getRequest } from '../../resources';
import { getClusterOperator } from '../../resources/clusteroperator';
import { getPodsOfNamespace } from '../../resources/pod';
import { delay, getZtpfwUrl } from '../utils';
import {
  DELAY_BEFORE_FINAL_REDIRECT,
  DELAY_BEFORE_QUERY_RETRY,
  MAX_LIVENESS_CHECK_COUNT,
  WAIT_ON_OPERATOR_TITLE,
  ZTPFW_NAMESPACE,
} from './constants';
import { PersistErrorType } from './types';

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

export const waitForClusterOperator = async (
  setError: (error: PersistErrorType) => void,
  name: string,
): Promise<boolean> => {
  console.info('waitForClusterOperator started for: ', name);
  for (let counter = 0; counter < MAX_LIVENESS_CHECK_COUNT; counter++) {
    try {
      console.log('Querying co: ', name);
      const operator = await getClusterOperator(name).promise;
      if (
        getCondition(operator, 'Progressing')?.status === 'False' &&
        getCondition(operator, 'Degraded')?.status === 'False' &&
        getCondition(operator, 'Available')?.status === 'True'
      ) {
        // all good
        setError(null);
        return true;
      }
    } catch (e) {
      console.error('waitForClusterOperator error: ', e);
      // do not report, keep trying
    }

    await delay(DELAY_BEFORE_QUERY_RETRY);
  }

  setError({
    title: WAIT_ON_OPERATOR_TITLE,
    message: `Failed to query status of ${name} cluster operator on time.`,
  });

  return false;
};
