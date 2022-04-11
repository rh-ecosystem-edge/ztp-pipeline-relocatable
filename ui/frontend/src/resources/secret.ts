import { Secret, SecretApiVersion, SecretKind } from '../common';
import { deleteResource, getResource } from './resource-request';

export const getSecret = (metadata: { name: string; namespace: string }) =>
  getResource<Secret>({
    apiVersion: SecretApiVersion,
    kind: SecretKind,
    metadata,
  });

export const deleteSecret = (metadata: { name: string; namespace: string }) =>
  deleteResource<Secret>({
    apiVersion: SecretApiVersion,
    kind: SecretKind,
    metadata,
  });
