import { ZTPFW_UI_ROUTE_PREFIX } from '../../copy-backend-common';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';
import { K8SStateContextData } from '../types';
import { bindOnBeforeUnloadPage, unbindOnBeforeUnloadPage } from '../utils';
import { MAX_LIVENESS_CHECK_COUNT, UI_POD_NOT_READY } from './constants';
import { persistDomain } from './persistDomain';
import { persistIdentityProvider, PersistIdentityProviderResult } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';
import { waitForClusterOperator, waitForZtpfwPodToBeRecreated } from './utils';

const waitOnReconciliation = async (
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

  if (!(await waitForClusterOperator(setError, 'kube-apiserver'))) {
    return false;
  }

  // Important: keep following aligned with the last reconcile-step
  setProgress(PersistSteps.ReconcileAuthOperator);

  console.info('waitOnReconciliation finished successfully');
  return true;
};

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  onSuccess: () => void,
) => {
  try {
    bindOnBeforeUnloadPage(
      'Data are being persisted. By leaving or refreshing the page, you will loose monitoring of the progress. Do you want to leave the page?',
    );

    const persistIdpResult = await persistIdentityProvider(
      setError,
      setProgress,
      state.username,
      state.password,
    );
    if (persistIdpResult === PersistIdentityProviderResult.error) {
      console.error('Failed to persist IDP, giving up.');
      return;
    }

    if (!(await saveIngress(setError, setProgress, state.ingressIp))) {
      console.error('Failed to persist Ingress IP, giving up.');
      return false;
    }

    if (!(await saveApi(setError, setProgress, state.apiaddr))) {
      console.error('Failed to persist API IP, giving up.');
      return false;
    }

    if (!(await persistDomain(setError, setProgress, state.domain, state.customCerts))) {
      return false;
    }

    // finished with success
    console.log('Data persisted, blocking progress till reconciled');

    setError(null); // show the green circle of success

    // Final check
    if (!(await waitOnReconciliation(setError, setProgress, state, persistIdpResult))) {
      return;
    }

    // delete route backup
    // TODO

    onSuccess();
  } finally {
    unbindOnBeforeUnloadPage();
  }
};

export const navigateToNewDomain = async (domain: string, contextPath: string) => {
  // We can not check livenessProbe on the new domain due to CORS
  // We can not use pod serving old domain either since it will be terminated and the route changed
  // So just wait...
  let ztpfwUrl: string;
  if (!domain) {
    // fallback
    ztpfwUrl = `${window.location.origin}${contextPath}`;
  } else {
    ztpfwUrl = `https://${ZTPFW_UI_ROUTE_PREFIX}.apps.${domain}${contextPath}`;
  }

  console.info('Changes are persisted, about to navigate to the new domain: ', ztpfwUrl);
  // We should go with following:
  window.location.replace(ztpfwUrl);
};
