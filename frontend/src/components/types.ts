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
