import { cloneDeep } from 'lodash';

import { createResource, deleteResource, patchResource } from '../../resources';
import { PatchType } from '../../resources/patches';
import { getService, Service } from '../../resources/service';
import { ipWithDots } from '../utils';
import { MISSING_VALUE, RESOURCE_CREATE_TITLE, RESOURCE_PATCH_TITLE } from './constants';
import {
  ADDRESS_POOL_ANNOTATION_KEY,
  ADDRESS_POOL_TEMPLATE,
  SERVICE_TEMPLATE_API,
  SERVICE_TEMPLATE_METALLB_INGRESS,
} from './resourceTemplates';
import { PersistErrorType } from './types';

const createAddressPool = async (
  setError: (error: PersistErrorType) => void,
  type: 'api' | 'ingress',
  serviceIp: string,
  namespace: string,
): Promise<string | undefined> => {
  try {
    const object = cloneDeep(ADDRESS_POOL_TEMPLATE);
    object.metadata.generateName = `kubeframe-${type}-`;
    object.metadata.namespace = namespace;
    object.spec.addresses = [`${serviceIp}-${serviceIp}`];

    const response = await createResource(object).promise;
    console.log('Resource created: ', response);

    return response.metadata.name;
  } catch (e) {
    console.error('Can not create resource: ', e);
    setError({
      title: RESOURCE_CREATE_TITLE,
      message: `Can not create ${type} AddressPool in the ${namespace} namespace.`,
    });
  }
  return undefined;
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

  const serviceIp = ipWithDots(_serviceIp);

  try {
    // Try to find existing resource. Decide about Add/Patch
    object = await getService({
      name,
      namespace,
    }).promise;

    if (object.spec?.loadBalancerIP !== serviceIp) {
      // Patch existing resource

      const addressPoolName = await createAddressPool(setError, type, serviceIp, namespace);
      if (!addressPoolName) {
        return false;
      }
      const oldAddressPoolName = object.metadata.annotations?.[ADDRESS_POOL_ANNOTATION_KEY];

      const patches: PatchType[] = [
        {
          op: object.spec?.loadBalancerIP === undefined ? 'add' : 'replace',
          path: '/spec/loadBalancerIP',
          value: serviceIp,
        },
      ];

      const annotations = object.metadata.annotations || {};
      annotations[ADDRESS_POOL_ANNOTATION_KEY] = addressPoolName;
      patches.push({
        op: object.metadata.annotations === undefined ? 'add' : 'replace',
        path: `/metadata/annotations`,
        value: annotations,
      });

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

      // Do clean-up
      try {
        if (oldAddressPoolName?.startsWith(`kubeframe-${type}-`)) {
          await deleteResource({
            apiVersion: ADDRESS_POOL_TEMPLATE.apiVersion,
            kind: ADDRESS_POOL_TEMPLATE.kind,
            metadata: {
              name: oldAddressPoolName,
              namespace,
            },
          }).promise;
        } else {
          console.info(
            `Skipping delete of "${oldAddressPoolName} AddressPool object. Is it still needed?`,
          );
        }
      } catch (e) {
        console.error(
          `Can not delete old ${oldAddressPoolName} AddressPool resource in the ${namespace} namespace.`,
        );
        // silently swallow this error, it's just clean-up
      }
    } else {
      console.log(`No changes to ${name} service detected. Skipping ${actionName}.`);
    }
  } catch (e) {
    // Create new resource
    const addressPoolName = await createAddressPool(setError, type, serviceIp, namespace);
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
): Promise<boolean> => saveService(setError, apiip, SERVICE_TEMPLATE_API, 'API IP', 'api');
