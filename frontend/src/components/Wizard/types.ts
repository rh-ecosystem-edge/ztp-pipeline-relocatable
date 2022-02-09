import { IpSelectorValidationType } from '../IpSelector';

export type WizardStateType = {
  mask: string; // 12 characters
  maskValidation: IpSelectorValidationType;
  handleSetMask: (newMask: string) => void;

  ip: string; // 12 characters
  ipValidation: IpSelectorValidationType;
  handleSetIp: (newIp: string) => void;
};
