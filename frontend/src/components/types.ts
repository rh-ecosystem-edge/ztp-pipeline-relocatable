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

export type K8SStateContextData = {
  username: string;
  usernameValidation?: string; // just a message or empty
  handleSetUsername: (newVal: string) => void;

  password: string;
  passwordValidation?: string;
  handleSetPassword: (newVal: string) => void;

  apiaddr: string; // 12 characters
  apiaddrValidation: IpTripletSelectorValidationType;
  handleSetApiaddr: (newApiaddr: string) => void;

  ingressIp: string; // 12 characters
  ingressIpValidation: IpTripletSelectorValidationType;
  handleSetIngressIp: (newIp: string) => void;

  domain: string;
  handleSetDomain: (newDomain: string) => void;
  domainValidation?: string;
};
