import { cloneDeep } from 'lodash';

import { createResource, patchResource } from '../../resources';
import { PatchType, Service } from '../../backend-shared';
import { getService } from '../../resources/service';
import { addIpDots } from '../utils';
import {
  ADDRESS_POOL_ANNOTATION_KEY,
  ADDRESS_POOL_NAMESPACE,
  API_LIVENESS_FAILED_TITLE,
  MISSING_VALUE,
  RESOURCE_CREATE_TITLE,
  RESOURCE_PATCH_TITLE,
} from './constants';
import {
  ADDRESS_POOL_TEMPLATE,
  SERVICE_TEMPLATE_API,
  SERVICE_TEMPLATE_METALLB_INGRESS,
} from './resourceTemplates';
import { PersistErrorType } from './types';
import { waitForLivenessProbe } from './utils';

const createAddressPool = async (
  setError: (error: PersistErrorType) => void,
  type: 'api' | 'ingress',
  serviceIp: string,
): Promise<string | undefined> => {
  try {
    const object = cloneDeep(ADDRESS_POOL_TEMPLATE);
    object.metadata.generateName = `ztpfw-${type}-`;
    // object.metadata.namespace = namespace;
    object.spec.addresses = [`${serviceIp}-${serviceIp}`];

    const response = await createResource(object).promise;
    console.log('Resource created: ', response);

    return response.metadata.name;
  } catch (e) {
    console.error('Can not create resource: ', e);
    setError({
      title: RESOURCE_CREATE_TITLE,
      message: `Can not create ${type} AddressPool in the ${ADDRESS_POOL_NAMESPACE} namespace.`,
    });
  }
  return undefined;
};

const patchAddressPool = async (
  setError: (error: PersistErrorType) => void,
  addressPoolName: string,
  serviceIp: string,
): Promise<boolean> => {
  const addrPoolObj = {
    // no need to fetch the resource, patch it right away
    apiVersion: ADDRESS_POOL_TEMPLATE.apiVersion,
    kind: ADDRESS_POOL_TEMPLATE.kind,
    metadata: {
      name: addressPoolName,
      namespace: ADDRESS_POOL_NAMESPACE,
    },
  };
  const addrPoolPatches = [
    {
      op: 'replace',
      path: '/spec/addresses',
      value: [`${serviceIp}-${serviceIp}`],
    },
  ];

  try {
    await patchResource(addrPoolObj, addrPoolPatches).promise;
    console.log(
      `Patched ${addressPoolName} AddressPool name in the ${ADDRESS_POOL_NAMESPACE} namespace`,
    );
  } catch (e) {
    console.error('Can not patch resource: ', e, addrPoolObj, addrPoolPatches);
    setError({
      title: RESOURCE_PATCH_TITLE,
      message: `Can not update ${addressPoolName} AddressPool in the ${ADDRESS_POOL_NAMESPACE} namespace.`,
    });
    return false;
  }

  return true;
};

const saveService = async (
  setError: (error: PersistErrorType) => void,
  _serviceIp: string,
  template: Service,
  actionName: string,
  type: 'api' | 'ingress',
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
        title: RESOURCE_CREATE_TITLE,
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
        title: RESOURCE_PATCH_TITLE,
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
  setError: (error: PersistErrorType) => void,
  ingressIp: string,
): Promise<boolean> =>
  saveService(setError, ingressIp, SERVICE_TEMPLATE_METALLB_INGRESS, 'ingress IP', 'ingress');

export const saveApi = async (
  setError: (error: PersistErrorType) => void,
  apiip: string,
): Promise<boolean> => {
  if (!(await saveService(setError, apiip, SERVICE_TEMPLATE_API, 'API IP', 'api'))) {
    return false;
  }

  if (!(await waitForLivenessProbe())) {
    setError({
      title: API_LIVENESS_FAILED_TITLE,
      message: 'Can not reach API on time.',
    });
    return false;
  }

  return true;
};
