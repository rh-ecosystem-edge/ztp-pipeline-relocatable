import { IpSelectorValidationType } from './IpSelector/types';
import { SingleIpDigitProps } from './SingleIpDigit';
import { WizardStateType } from './Wizard/types';

const DNS_NAME_REGEX = /^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$/;
const SSH_PUBLIC_KEY_REGEX =
  /^(ssh-rsa|ssh-ed25519|ecdsa-[-a-z0-9]*) AAAA[0-9A-Za-z+/]+[=]{0,3}( .+)?$/;
const USERNAME_REGEX = /^[a-z]([-a-z0-9]*[a-z0-9])?$/;

export const addIpDots = (addressWithoutDots: string): string => {
  if (addressWithoutDots?.length === 12) {
    let address = addressWithoutDots.substring(0, 3) + '.';
    address += addressWithoutDots.substring(3, 6) + '.';
    address += addressWithoutDots.substring(6, 9) + '.';
    address += addressWithoutDots.substring(9);

    console.log('-- addressWithoutDots: ', addressWithoutDots, ' to ', address);
    return address;
  }

  throw Error('Invalid address: ' + addressWithoutDots);
};

const validateIpTripplet = (
  isMask: boolean,
  a: string,
  b: string,
  c: string,
): { valid: boolean; digits: SingleIpDigitProps['validated'][] } => {
  a = a.trim();
  b = b.trim();
  c = c.trim();

  if (!isMask && a === '0' && b === '0' && c === '0') {
    return { valid: false, digits: ['error', 'error', 'error'] };
  }

  if (a) {
    if (!['0', '1', '2'].includes(a)) {
      return { valid: false, digits: ['error', 'default', 'default'] };
    }
    if (a === '2') {
      if (b) {
        if (parseInt(b) > 5) {
          return { valid: false, digits: ['success', 'error', 'default'] };
        }
        if (parseInt(b) === 5 && c && parseInt(c) > 5) {
          return { valid: false, digits: ['success', 'success', 'error'] };
        }
      } else {
        return { valid: true, digits: ['success', 'default', 'success'] };
      }
    }
    return { valid: true, digits: ['success', 'success', 'success'] };
  }

  return { valid: true, digits: ['default', 'default', 'default'] };
};

export const ipAddressValidator = (addr: string, isMask: boolean): IpSelectorValidationType => {
  const validation: IpSelectorValidationType = { valid: true, digits: [] };

  for (let i = 0; i <= 3; i++) {
    const triplet = validateIpTripplet(
      isMask,
      addr.charAt(3 * i),
      addr.charAt(3 * i + 1),
      addr.charAt(3 * i + 2),
    );
    validation.valid = validation.valid && triplet.valid;
    validation.digits = validation.digits.concat(triplet.digits);
  }

  return validation;
};

export const domainValidator = (domain: string): WizardStateType['domainValidation'] => {
  if (domain.match(DNS_NAME_REGEX)) {
    return ''; // passed
  }
  return "Valid domain wasn't provided";
};

export const sshPubKeyValidator = (key: string): WizardStateType['sshPubKeyValidation'] => {
  if (!key || key.match(SSH_PUBLIC_KEY_REGEX)) {
    return ''; // passed
  }

  return "Valid public SSH key wasn't provided";
};

export const usernameValidator = (username = ''): WizardStateType['username'] => {
  if (username.length >= 54) {
    return 'Valid username can not be longer than 54 characters.';
  }

  if (!username || username.match(USERNAME_REGEX)) {
    return ''; // passed
  }

  return "Valid username wasn't provided";
};

export const passwordValidator = (pwd = ''): WizardStateType['password'] => {
  if (pwd.length <= 8) {
    return 'Valid password can not be shorter then 8 symbols';
  }

  // TODO(mlibra): add more conditions here
  return ''; // passed
};
