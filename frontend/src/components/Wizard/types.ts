import { IpSelectorValidationType } from '../IpSelector';

export type WizardStateType = {
  apiaddr: string; // 12 characters
  apiaddrValidation: IpSelectorValidationType;
  handleSetApiaddr: (newApiaddr: string) => void;

  ingressIp: string; // 12 characters
  ingressIpValidation: IpSelectorValidationType;
  handleSetIngressIp: (newIp: string) => void;

  domain: string;
  handleSetDomain: (newDomain: string) => void;
  domainValidation?: string; // just a message or empty

  sshPubKey?: string;
  handleSetSshPubKey: (newKey: string | File) => void;
  sshPubKeyValidation?: string;
};
