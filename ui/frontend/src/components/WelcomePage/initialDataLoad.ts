import { getService } from '../../resources/service';
import { K8SStateContextData } from '../types';
import {
  SERVICE_TEMPLATE_API,
  SERVICE_TEMPLATE_METALLB_INGRESS,
} from '../PersistPage/resourceTemplates';
import { ipWithoutDots } from '../utils';
import { getHtpasswdIdentityProvider, getOAuth } from '../../resources/oauth';

export const initialDataLoad = async ({
  setNextPage,
  setError,
  handleSetApiaddr,
  handleSetIngressIp,
}: {
  setNextPage?: (href: string) => void;
  setError: (message?: string) => void;
  handleSetApiaddr: K8SStateContextData['handleSetApiaddr'];
  handleSetIngressIp: K8SStateContextData['handleSetIngressIp'];
}) => {
  let ingressService, apiService, oauth;
  try {
    oauth = await getOAuth().promise;
    ingressService = await getService({
      name: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.name || '',
      namespace: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.namespace || '',
    }).promise;
    apiService = await getService({
      name: SERVICE_TEMPLATE_API.metadata.name || '',
      namespace: SERVICE_TEMPLATE_API.metadata.namespace || '',
    }).promise;
  } catch (_e) {
    const e = _e as { message: string; code: number };
    if (e.code !== 404) {
      console.error(e, e.code);
      setError('Failed to contact OpenShift Platform API.');
      return;
    }
  }

  if (ingressService?.spec?.loadBalancerIP) {
    handleSetIngressIp(ipWithoutDots(ingressService.spec?.loadBalancerIP));
  }
  if (apiService?.spec?.loadBalancerIP) {
    handleSetApiaddr(ipWithoutDots(apiService?.spec?.loadBalancerIP));
  }
  // TODO: read & set the domain

  if (getHtpasswdIdentityProvider(oauth)) {
    // The Edit flow for the 2nd and later run
    setNextPage && setNextPage('/settings');
    return;
  }

  // The Wizard for the very first run
  setNextPage && setNextPage('/wizard/username');
};
