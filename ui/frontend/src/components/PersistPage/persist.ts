import { K8SStateContextData } from '../types';
import { MAX_LIVENESS_CHECK_COUNT, UI_POD_NOT_READY, ZTPFW_UI_ROUTE_PREFIX } from './constants';
import { persistDomain } from './persistDomain';
import { persistIdentityProvider, PersistIdentityProviderResult } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';
import { waitForZtpfwPodToBeRecreated } from './utils';

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

    // wait till the UI pod is recreated after changing domain (Deployment + route)
    if (!(await waitForZtpfwPodToBeRecreated(MAX_LIVENESS_CHECK_COUNT, state.domain))) {
      setError({
        title: UI_POD_NOT_READY,
        message: 'The configuration pod did not become ready on time.',
      });
      return;
    }

    if (persistIdpResult === PersistIdentityProviderResult.userCreated) {
      // wait for identity provider
      // Assumption: since we have waited in the previous step, it should be good enough to wait on pods in openshift-authentication namespace to become ready
      // TODO
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
