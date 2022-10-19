import { cloneDeep } from 'lodash';
import { createResource, patchResource } from '../resources';
import { ADDRESS_POOL_NAMESPACE } from './constants';
import { setUIErrorType } from './types';

const ADDRESS_POOL_TEMPLATE = {
  apiVersion: 'metallb.io/v1alpha1',
  kind: 'AddressPool',
  metadata: {
    generateName: 'ztpfw-', // To be filled
    name: '',
    namespace: ADDRESS_POOL_NAMESPACE,
  },
  spec: {
    protocol: 'layer2',
    addresses: [
      '', // To be filled, example: '172.18.0.100-172.18.0.255',
    ],
  },
};

export const createAddressPool = async (
  setError: setUIErrorType,
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
      title: 'Resource create failed',
      message: `Can not create ${type} AddressPool in the ${ADDRESS_POOL_NAMESPACE} namespace.`,
    });
  }
  return undefined;
};

export const patchAddressPool = async (
  setError: setUIErrorType,
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
      title: 'Resource update failed',
      message: `Can not update ${addressPoolName} AddressPool in the ${ADDRESS_POOL_NAMESPACE} namespace.`,
    });
    return false;
  }

  return true;
};
