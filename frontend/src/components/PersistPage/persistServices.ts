import { cloneDeep } from 'lodash';

import { createResource, patchResource } from '../../resources';
import { PatchType } from '../../resources/patches';
import { getService, Service } from '../../resources/service';
import { ipWithDots } from '../utils';
import { MISSING_VALUE, RESOURCE_CREATE_TITLE, RESOURCE_PATCH_TITLE } from './constants';
import { SERVICE_TEMPLATE_API, SERVICE_TEMPLATE_METALLB_INGRESS } from './resourceTemplates';
import { PeristsErrorType } from './types';

const saveService = async (
  setError: (error: PeristsErrorType) => void,
  _serviceIp: string,
  template: Service,
  actionName: string,
): Promise<boolean> => {
  if (!(_serviceIp?.replaceAll(' ', '').length >= 4)) {
    setError({
      title: MISSING_VALUE,
      message: `Missing value for ${actionName}`,
    });
    return false;
  }

  let object: Service;
  const name = template.metadata.name || '';
  const namespace = template.metadata.namespace || '';

  const serviceIp = ipWithDots(_serviceIp);

  try {
    // Try to find existing resource. Decide about Add/Patch
    object = await getService({
      name,
      namespace,
    }).promise;

    if (object.spec?.loadBalancerIP !== serviceIp) {
      // Patch existing resource
      const patches: PatchType[] = [
        {
          op: object.spec?.loadBalancerIP === undefined ? 'add' : 'replace',
          path: '/spec/loadBalancerIP',
          value: serviceIp,
        },
      ];

      try {
        const response = await patchResource(object, patches).promise;
        console.log(`Patched ${actionName} service: `, response);
      } catch (e) {
        console.error('Can not patch resource: ', e, object, patches);
        setError({
          title: RESOURCE_PATCH_TITLE,
          message: `Can not update ${name} service in the ${namespace} namespace for ${actionName}.`,
        });
        return false;
      }
    } else {
      console.log(`No changes to ${name} service detected. Skipping ${actionName}.`);
    }
  } catch (e) {
    // Create new resource
    object = cloneDeep(template);
    object.spec && (object.spec.loadBalancerIP = serviceIp);
    try {
      const response = await createResource(object).promise;
      console.log('Resource created: ', response);
    } catch (e) {
      console.error('Can not create resource: ', e);
      setError({
        title: RESOURCE_CREATE_TITLE,
        message: `Can not create ${name} service in the ${namespace} namespace for ${actionName}.`,
      });
      return false;
    }
  }

  return true;
};

export const saveIngress = async (
  setError: (error: PeristsErrorType) => void,
  ingressIp: string,
): Promise<boolean> =>
  saveService(setError, ingressIp, SERVICE_TEMPLATE_METALLB_INGRESS, 'ingress IP');

export const saveApi = async (
  setError: (error: PeristsErrorType) => void,
  apiip: string,
): Promise<boolean> => saveService(setError, apiip, SERVICE_TEMPLATE_API, 'API IP');
