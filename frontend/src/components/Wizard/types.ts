import { IpTripletSelectorValidationType } from '../types';

export type WizardStateType = {
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

  sshPubKey?: string;
  handleSetSshPubKey: (newKey: string | File) => void;
  sshPubKeyValidation?: string;
};
