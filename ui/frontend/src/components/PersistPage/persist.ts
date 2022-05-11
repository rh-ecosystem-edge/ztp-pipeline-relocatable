import { getCondition } from '../../copy-backend-common';
import { getClusterOperator } from '../../resources/clusteroperator';
import { K8SStateContextData } from '../types';
import { delay } from '../utils';
import {
  DELAY_BEFORE_QUERY_RETRY,
  MAX_LIVENESS_CHECK_COUNT,
  UI_POD_NOT_READY,
  WAIT_ON_OPERATOR_TITLE,
  ZTPFW_UI_ROUTE_PREFIX,
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
      // keep trying

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

  if (persistIdpResult === PersistIdentityProviderResult.userCreated) {
    // wait for API
    if (!(await waitForClusterOperator(setError, 'openshift-apiserver'))) {
      return false;
    }

    // wait for identity provider
    if (!(await waitForClusterOperator(setError, 'authentication'))) {
      return false;
    }

    // TODO: openshift console??
  }

  console.info('waitOnreconciliation finished successfully');
  return true;
};

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  onSuccess: () => void,
) => {
  const persistIdpResult = await persistIdentityProvider(setError, state.username, state.password);
  if (
    persistIdpResult !== PersistIdentityProviderResult.error &&
    (await saveIngress(setError, state.ingressIp)) &&
    (await saveApi(setError, state.apiaddr)) &&
    (await persistDomain(setError, state.domain))
  ) {
    // finished with success
    console.log('Data persisted, blocking progress till reconciled');

    setError(null); // show the green circle of success

    // TODO: show progress bar while waiting
    if (!(await waitOnreconciliation(setError, state, persistIdpResult))) {
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
