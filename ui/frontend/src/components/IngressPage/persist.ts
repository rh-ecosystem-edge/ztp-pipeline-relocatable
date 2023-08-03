import { cloneDeep } from 'lodash';

import { PatchType, Service } from '../../copy-backend-common';
import { createResource, patchResource } from '../../resources';
import { getService } from '../../resources/service';
import { createAddressPool, patchAddressPool } from '../addressPool';
import { ADDRESS_POOL_ANNOTATION_KEY } from '../constants';
import { setUIErrorType } from '../types';
import { addIpDots } from '../utils';

import { SERVICE_TEMPLATE_METALLB_INGRESS } from './template';

export const saveService = async (
  setError: setUIErrorType,
  _serviceIp: string,
  template: Service,
  actionName: string,
  type: 'api' | 'ingress',
): Promise<boolean> => {
  if (!(_serviceIp?.replaceAll(' ', '').length >= 4)) {
    setError({
      title: 'Missing value',
      message: `Missing value for ${actionName}`,
    });
    return false;
  }

  let object: Service;
  const name = template.metadata.name || '';
  const namespace = template.metadata.namespace || '';

  const serviceIp = addIpDots(_serviceIp);

  try {
    // Try to find existing service resource. To decide about Add/Patch
    object = await getService({
      name,
      namespace,
    }).promise;
  } catch (e) {
    // Service resource not found - create new one
    const addressPoolName = await createAddressPool(setError, type, serviceIp);
    if (!addressPoolName) {
      return false;
    }

    object = cloneDeep(template);
    object.spec && (object.spec.loadBalancerIP = serviceIp);
    object.metadata.annotations = object.metadata.annotations || {};
    object.metadata.annotations[ADDRESS_POOL_ANNOTATION_KEY] = addressPoolName;

    try {
      const response = await createResource(object).promise;
      console.log('Resource created: ', response);
    } catch (e) {
      console.error('Can not create resource: ', e);
      setError({
        title: 'Resource create failed',
        message: `Can not create ${name} service in the ${namespace} namespace for ${actionName}.`,
      });
      return false;
    }

    // New Service and AddressPool created
    return true;
  }

  // Patch existing Service
  if (object.spec?.loadBalancerIP !== serviceIp) {
    // if there's a change
    const patches: PatchType[] = [
      {
        op: object.spec?.loadBalancerIP === undefined ? 'add' : 'replace',
        path: '/spec/loadBalancerIP',
        value: serviceIp,
      },
    ];

    const serviceAnnotations = object.metadata.annotations || {};
    let addressPoolName: string | undefined = serviceAnnotations?.[ADDRESS_POOL_ANNOTATION_KEY];
    if (addressPoolName) {
      // The AddressPool resource already exists, patch it
      if (!(await patchAddressPool(setError, addressPoolName, serviceIp))) {
        return false;
      }
    } else {
      // The AddressPool resource does not exist yet, create it
      addressPoolName = await createAddressPool(setError, type, serviceIp);
      if (!addressPoolName) {
        return false;
      }

      serviceAnnotations[ADDRESS_POOL_ANNOTATION_KEY] = addressPoolName;
      patches.push({
        op: object.metadata.annotations === undefined ? 'add' : 'replace',
        path: `/metadata/annotations`,
        value: serviceAnnotations,
      });
    }

    try {
      const response = await patchResource(object, patches).promise;
      console.log(`Patched ${actionName} service: `, response);
    } catch (e) {
      console.error('Can not patch resource: ', e, object, patches);
      setError({
        title: 'Resource update failed',
        message: `Can not update ${name} service in the ${namespace} namespace for ${actionName}.`,
      });
      return false;
    }
  } else {
    console.log(`No changes to ${name} service detected. Skipping ${actionName}.`);
  }

  return true;
};

export const saveIngress = async (
  setError: setUIErrorType,
  ingressIp: string,
): Promise<boolean> => {
  const result = saveService(
    setError,
    ingressIp,
    SERVICE_TEMPLATE_METALLB_INGRESS,
    'ingress IP',
    'ingress',
  );

  // TODO: Block progress here

  return result;
};
