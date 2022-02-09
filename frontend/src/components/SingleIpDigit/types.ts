import { TextInputProps } from '@patternfly/react-core';

export type IpDigitIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;

export type SingleIpDigitProps = {
  position: IpDigitIndex;
  focus: IpDigitIndex;
  address: string;
  setAddress: (newAddress: string) => void;
  setFocus: (newPosition: IpDigitIndex) => void;
  validated: TextInputProps['validated'];
};
