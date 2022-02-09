import { SingleIpDigitProps } from '../SingleIpDigit/types';

export type IpSelectorValidationType = {
  valid: boolean;
  message?: string;
  digits: SingleIpDigitProps['validated'][];
};
