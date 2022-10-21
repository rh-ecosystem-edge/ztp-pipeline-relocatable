import { FormGroupProps, TextInputProps } from '@patternfly/react-core';
import { CustomCertsType, TlsCertificate } from '../copy-backend-common';

export type UIError = {
  title: string;
  message?: string;
};

export type setUIErrorType = (error?: UIError) => void;

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
  isDisabled?: boolean;
};

export type IpTripletSelectorValidationType = {
  valid: boolean;
  message?: string;
  triplets: IpTripletProps['validated'][];
};

export type CertificateProps = {
  name: string;
  domain: string;

  customCerts: CustomCertsType;
  setCustomCertificate: (domain: string, certificate: TlsCertificate) => void;
  customCertsValidation: CustomCertsValidationType;

  isSpaceItemsNone?: boolean;
};

export type CustomCertsValidationType = {
  [key: string]: {
    certValidated: FormGroupProps['validated'];
    certLabelHelperText?: string;
    certLabelInvalid?: string;

    keyValidated: FormGroupProps['validated'];
    keyLabelInvalid?: string;
  };
};
