export interface OwnerReference {
  apiVersion: string;
  kind: string;
  name: string;
  uid: string;
}
export interface Metadata {
  name?: string;
  namespace?: string;
  resourceVersion?: string;
  creationTimestamp?: string;
  uid?: string;
  annotations?: Record<string, string>;
  labels?: Record<string, string>;
  generateName?: string;
  deletionTimestamp?: string;
  selfLink?: string;
  finalizers?: string[];
  ownerReferences?: OwnerReference[];
}
