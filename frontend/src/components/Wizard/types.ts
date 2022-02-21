import { IpSelectorValidationType } from '../IpSelector';

export type WizardStateType = {
  username: string;
  usernameValidation?: string; // just a message or empty
  handleSetUsername: (newVal: string) => void;

  password: string;
  passwordValidation?: string;
  handleSetPassword: (newVal: string) => void;

  apiaddr: string; // 12 characters
  apiaddrValidation: IpSelectorValidationType;
  handleSetApiaddr: (newApiaddr: string) => void;

  ingressIp: string; // 12 characters
  ingressIpValidation: IpSelectorValidationType;
  handleSetIngressIp: (newIp: string) => void;

  domain: string;
  handleSetDomain: (newDomain: string) => void;
  domainValidation?: string;

  sshPubKey?: string;
  handleSetSshPubKey: (newKey: string | File) => void;
  sshPubKeyValidation?: string;
};
