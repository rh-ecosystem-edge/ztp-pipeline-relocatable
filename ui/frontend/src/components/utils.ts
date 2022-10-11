import { FormGroupProps } from '@patternfly/react-core';
import { Buffer } from 'buffer';

import { DNS_NAME_REGEX, USERNAME_REGEX } from '../backend-shared';
import { TlsCertificate } from '../copy-backend-common';
import { isPasswordPolicyMet } from './PasswordPage/utils';
import { IpTripletSelectorValidationType, K8SStateContextData } from './types';

export const toBase64 = (str: string) => Buffer.from(str).toString('base64');
export const fromBase64ToUtf8 = (b64Str?: string): string | undefined =>
  b64Str === undefined ? undefined : Buffer.from(b64Str, 'base64').toString('utf8');

export const addIpDots = (addressWithoutDots: string): string => {
  if (addressWithoutDots?.length === 12) {
    let address = addressWithoutDots.substring(0, 3).trim() + '.';
    address += addressWithoutDots.substring(3, 6).trim() + '.';
    address += addressWithoutDots.substring(6, 9).trim() + '.';
    address += addressWithoutDots.substring(9).trim();

    return address;
  }

  throw new Error('Invalid address: ' + addressWithoutDots);
};

export const ipTripletAddressValidator = (
  addr: string,
  reservedIp?: string,
): IpTripletSelectorValidationType => {
  const validation: IpTripletSelectorValidationType = { valid: true, triplets: [] };

  for (let i = 0; i <= 3; i++) {
    const triplet = addr.substring(i * 3, (i + 1) * 3).trim();
    const num = parseInt(triplet);
    const valid = num >= 0 && num <= 255;

    validation.valid = validation.valid && valid;
    validation.triplets.push(valid ? 'success' : 'default');
  }

  if (!validation.valid) {
    validation.message = 'Provided IP address is incorrect.';
  }

  if (reservedIp === addr) {
    validation.message = 'Provided IP address is already used.';
    validation.valid = false;
  }

  const dottedIp = addIpDots(addr);
  if (dottedIp === '255.255.255.255' || dottedIp === '127.0.0.1' || dottedIp === '0.0.0.0') {
    validation.message = 'Provided IP address is reserved.';
    validation.valid = false;
  }

  // We do not know subnet, the user _is expected_ not to provide subnet address or broadcast

  return validation;
};

export const domainValidator = (domain: string): K8SStateContextData['domainValidation'] => {
  if (!domain || domain?.match(DNS_NAME_REGEX)) {
    return ''; // passed ; optional - pass for empty as well
  }
  return "Valid domain wasn't provided.";
};

export const usernameValidator = (username = ''): K8SStateContextData['username'] => {
  if (username.length >= 54) {
    return 'Valid username can not be longer than 54 characters.';
  }

  if (username === 'kubeadmin') {
    return 'The kubeadmin username is reserved.';
  }

  if (!username || username.match(USERNAME_REGEX)) {
    return ''; // passed
  }

  return "Valid username wasn't provided.";
};

export const passwordValidator = (pwd: string): K8SStateContextData['passwordValidation'] => {
  return isPasswordPolicyMet(pwd);
};

export const customCertsValidator = (
  oldValidation: K8SStateContextData['customCertsValidation'],
  domain: string,
  certificate: TlsCertificate,
): K8SStateContextData['customCertsValidation'] => {
  const validation: K8SStateContextData['customCertsValidation'] = { ...oldValidation };

  let certValidated: FormGroupProps['validated'] = 'default';
  let certLabelHelperText = '';
  let certLabelInvalid = '';
  if (!certificate?.['tls.crt'] && certificate?.['tls.key']) {
    certValidated = 'error';
    certLabelInvalid = 'Both key and certificate must be provided at once.';
  } else if (!certificate?.['tls.crt']) {
    certLabelHelperText =
      'When not uploaded, a self-signed certificate will be generated automatically.';
  }

  let keyValidated: FormGroupProps['validated'] = 'default';
  let keyLabelInvalid = '';
  if (certificate?.['tls.crt'] && !certificate?.['tls.key']) {
    keyValidated = 'error';
    keyLabelInvalid = 'Both key and certificate must be provided at once.';
  }

  const tlsCrt = fromBase64ToUtf8(certificate['tls.crt'])?.trim().split('\n');
  const tlsKey = fromBase64ToUtf8(certificate['tls.key'])?.trim().split('\n');
  if (tlsCrt?.length && tlsKey?.length && tlsCrt.length > 2 && tlsKey.length > 2) {
    // The header/footer are not required but commonly used, so let's try to check the format based on them
    if (
      !tlsCrt[0].includes('--BEGIN CERTIFICATE--') ||
      !tlsCrt?.[tlsCrt.length - 1].includes('--END CERTIFICATE--')
    ) {
      certValidated = 'error';
      certLabelInvalid = 'The provided certificate does not conform PEM format.';
    } else {
      certValidated = 'success';
    }

    if (
      !tlsKey[0].includes('--BEGIN PRIVATE KEY--') ||
      !tlsKey?.[tlsKey.length - 1].includes('--END PRIVATE KEY--')
    ) {
      keyValidated = 'error';
      keyLabelInvalid = 'The provided key does not conform PEM format.';
    } else {
      keyValidated = 'success';
    }
  }

  validation[domain] = {
    certValidated,
    certLabelHelperText,
    certLabelInvalid,

    keyValidated,
    keyLabelInvalid,
  };

  return validation;
};

export const ipWithoutDots = (ip?: string): string => {
  if (ip) {
    const triplets = ip.split('.');
    if (triplets.length === 4) {
      let result = triplets[0].padStart(3, ' ');
      result += triplets[1].padStart(3, ' ');
      result += triplets[2].padStart(3, ' ');
      result += triplets[3].padStart(3, ' ');
      return result;
    }
  }

  console.info('Unrecognized ip address format "', ip, '"');
  return '            '; // 12 characters
};

export const delay = (ms: number) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const getZtpfwUrl = () => `https://${window.location.hostname}:${window.location.port}`;

export const bindOnBeforeUnloadPage = (message: string) => {
  if (window.onbeforeunload) {
    console.error('There is already window.onbeforeunload registered!! Rewriting it.');
  }

  window.onbeforeunload = () => message;
};

export const unbindOnBeforeUnloadPage = () => {
  window.onbeforeunload = null;
};

export const getLoginCallbackUrl = () => `${window.location.origin}/login/callback`;

// Relative URIs only are allowed here. The only exception is OCP Web Console
export const getAuthorizationEndpointUrl = () =>
  `/oauth/authorize?response_type=code&client_id=ztpfwoauth&redirect_uri=${getLoginCallbackUrl()}&scope=user%3Afull&state=`;
