import { DELAY_BEFORE_RECONCILIATION } from '../constants';
import { saveService } from '../IngressPage/persist';
import { setUIErrorType } from '../types';
import { delay, waitForClusterOperator, waitForLivenessProbe } from '../utils';

import { SERVICE_TEMPLATE_API } from './template';

export const saveApi = async (setError: setUIErrorType, apiIp: string): Promise<boolean> => {
  if (!(await saveService(setError, apiIp, SERVICE_TEMPLATE_API, 'API IP', 'api'))) {
    return false;
  }

  // Let the reconciliation start
  await delay(DELAY_BEFORE_RECONCILIATION);

  if (!(await waitForLivenessProbe())) {
    setError({
      title: 'API can not be reached',
      message: 'Can not reach API on time after API IP change .',
    });
    return false;
  }

  if (!(await waitForClusterOperator(setError, 'kube-apiserver'))) {
    setError({
      title: 'Kube API server can not be reached',
      message:
        'Reconciliation of the kube-apiserver operator did not finish on time after API IP change .',
    });
    return false;
  }

  if (!(await waitForClusterOperator(setError, 'openshift-apiserver'))) {
    setError({
      title: 'OpenShift API server can not be reached',
      message:
        'Reconciliation of the openshift-apiserver operator did not finish on time after API IP change.',
    });
    return false;
  }

  if (!(await waitForClusterOperator(setError, 'authentication'))) {
    // troublemaker
    setError({
      title: 'Authentication can not be reached',
      message:
        'Reconciliation of the authentication operator did not finish on time after API IP change .',
    });
    return false;
  }

  return true;
};
