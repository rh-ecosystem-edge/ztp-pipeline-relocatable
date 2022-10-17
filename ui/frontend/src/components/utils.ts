import { EMPTY_VIP } from './constants';
import { IpTripletSelectorValidationType } from './types';

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
  return EMPTY_VIP; // 12 characters
};

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

export const delay = (ms: number) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const getZtpfwUrl = () => `https://${window.location.hostname}:${window.location.port}`;
