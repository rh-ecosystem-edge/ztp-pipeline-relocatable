import { TextInputProps } from '@patternfly/react-core';

export type IpTripletIndex = 0 | 1 | 2 | 3;

export type IpTripletProps = {
  position: IpTripletIndex;
  focus: IpTripletIndex | null;
  address: string;
  setAddress: (newAddress: string) => void;
  setFocus: (newPosition: IpTripletIndex | null) => void;
  validated: TextInputProps['validated'];
};

export type IpDigitIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;

export type SingleIpDigitProps = {
  position: IpDigitIndex;
  focus: IpDigitIndex;
  address: string;
  setAddress: (newAddress: string) => void;
  setFocus: (newPosition: IpDigitIndex) => void;
  validated: TextInputProps['validated'];
};

export type IpSelectorValidationType = {
  valid: boolean;
  message?: string;
  digits: SingleIpDigitProps['validated'][];
};

export type IpTripletSelectorValidationType = {
  valid: boolean;
  message?: string;
  triplets: IpTripletProps['validated'][];
};
