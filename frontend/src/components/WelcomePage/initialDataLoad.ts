import { getService } from '../../resources/service';
import { K8SStateContextData } from '../K8SStateContext';
import {
  SERVICE_TEMPLATE_API,
  SERVICE_TEMPLATE_METALLB_INGRESS,
} from '../PersistPage/resourceTemplates';
import { ipWithoutDots } from '../utils';

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
  try {
    const ingressService = await getService({
      name: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.name || '',
      namespace: SERVICE_TEMPLATE_METALLB_INGRESS.metadata.namespace || '',
    }).promise;
    const apiService = await getService({
      name: SERVICE_TEMPLATE_API.metadata.name || '',
      namespace: SERVICE_TEMPLATE_API.metadata.namespace || '',
    }).promise;

    if (ingressService.spec?.loadBalancerIP) {
      handleSetIngressIp(ipWithoutDots(ingressService.spec?.loadBalancerIP));
      handleSetApiaddr(ipWithoutDots(apiService.spec?.loadBalancerIP));
      // TODO: domain

      // The Edit flow for the 2nd and later run
      setNextPage && setNextPage('/settings');
      return;
    }

    // The Wizard for the first run
    setNextPage && setNextPage('/wizard/username');
  } catch (e) {
    console.error(e);
    setError('Failed to contact OpenShift Platform API.');
  }
};
