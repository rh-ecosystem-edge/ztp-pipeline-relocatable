import { TextInputProps } from '@patternfly/react-core';

export type IpTripletIndex = 0 | 1 | 2 | 3;

export type IpTripletProps = {
  id: string;
  position: IpTripletIndex;
  focus: IpTripletIndex | null;
  address: string;
  setAddress: (newAddress: string) => void;
  setFocus: (newPosition: IpTripletIndex | null) => void;
  validated: TextInputProps['validated'];
  isNarrow?: boolean;
};

export type IpTripletSelectorValidationType = {
  valid: boolean;
  message?: string;
  triplets: IpTripletProps['validated'][];
};

export type K8SStateContextDataFields = {
  username: string;
  password: string;
  apiaddr: string; // 12 characters
  ingressIp: string; // 12 characters
  domain: string;
};

export type K8SStateContextData = K8SStateContextDataFields & {
  isDirty: () => boolean;
  setClean: () => void;

  usernameValidation?: string; // just a message or empty
  handleSetUsername: (newVal: string) => void;

  passwordValidation: boolean;
  handleSetPassword: (newVal: string) => void;

  apiaddrValidation: IpTripletSelectorValidationType;
  handleSetApiaddr: (newApiaddr: string) => void;

  ingressIpValidation: IpTripletSelectorValidationType;
  handleSetIngressIp: (newIp: string) => void;

  handleSetDomain: (newDomain: string) => void;
  domainValidation?: string;
};
