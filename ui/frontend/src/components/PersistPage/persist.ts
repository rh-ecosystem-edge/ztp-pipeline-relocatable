import { getCondition, ZTPFW_UI_ROUTE_PREFIX } from '../../copy-backend-common';
import { getClusterOperator } from '../../resources/clusteroperator';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';
import { K8SStateContextData } from '../types';
import { delay } from '../utils';
import {
  DELAY_BEFORE_QUERY_RETRY,
  MAX_LIVENESS_CHECK_COUNT,
  UI_POD_NOT_READY,
  WAIT_ON_OPERATOR_TITLE,
} from './constants';
import { persistDomain } from './persistDomain';
import { persistIdentityProvider, PersistIdentityProviderResult } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';
import { waitForZtpfwPodToBeRecreated } from './utils';

const waitForClusterOperator = async (
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

      // setError({
      //   title: WAIT_ON_OPERATOR_TITLE,
      //   message: `Failed to query status of ${name} cluster operator`,
      // });
    }

    await delay(DELAY_BEFORE_QUERY_RETRY);
  }

  setError({
    title: WAIT_ON_OPERATOR_TITLE,
    message: `Failed to query status of ${name} cluster operator on time.`,
  });

  return false;
};

const waitOnreconciliation = async (
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  state: K8SStateContextData,
  persistIdpResult: PersistIdentityProviderResult,
): Promise<boolean> => {
  const { domain } = state;

  // wait till the UI pod is recreated after changing domain (Deployment + route)
  if (!(await waitForZtpfwPodToBeRecreated(MAX_LIVENESS_CHECK_COUNT, domain))) {
    setError({
      title: UI_POD_NOT_READY,
      message: 'The configuration pod did not become ready on time.',
    });
    return false;
  }
  setProgress(PersistSteps.ReconcileUIPod);

  if (persistIdpResult === PersistIdentityProviderResult.userCreated) {
    // wait for API
    if (!(await waitForClusterOperator(setError, 'openshift-apiserver'))) {
      return false;
    }
    setProgress(PersistSteps.ReconcileApiOperator);

    // wait for identity provider
    if (!(await waitForClusterOperator(setError, 'authentication'))) {
      return false;
    }
    setProgress(PersistSteps.ReconcileAuthOperator);

    // TODO: openshift console??
  }

  // Important: keep following aligned with the last reconcile-step
  setProgress(PersistSteps.ReconcileAuthOperator);

  console.info('waitOnreconciliation finished successfully');
  return true;
};

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  onSuccess: () => void,
) => {
  const persistIdpResult = await persistIdentityProvider(
    setError,
    setProgress,
    state.username,
    state.password,
  );
  if (
    (await persistDomain(setError, setProgress, state.domain, state.customCerts)) &&
    persistIdpResult !== PersistIdentityProviderResult.error &&
    (await saveIngress(setError, setProgress, state.ingressIp)) &&
    (await saveApi(setError, setProgress, state.apiaddr)) &&
    (await persistDomain(setError, setProgress, state.domain, state.customCerts))
  ) {
    // finished with success
    console.log('Data persisted, blocking progress till reconciled');

    setError(null); // show the green circle of success

    // TODO: show progress bar while waiting
    if (!(await waitOnreconciliation(setError, setProgress, state, persistIdpResult))) {
      return;
    }

    // delete route backup
    // TODO

    onSuccess();
  }
};

export const navigateToNewDomain = async (domain: string, contextPath: string) => {
  // We can not check livenessProbe on the new domain due to CORS
  // We can not use pod serving old domain either since it will be terminated and the route changed
  // So just wait...
  const ztpfwUrl = `https://${ZTPFW_UI_ROUTE_PREFIX}.apps.${domain}${contextPath}`;
  console.info('Changes are persisted, about to navigate to the new domain: ', ztpfwUrl);
  // We should go with following:
  window.location.replace(ztpfwUrl);
};
