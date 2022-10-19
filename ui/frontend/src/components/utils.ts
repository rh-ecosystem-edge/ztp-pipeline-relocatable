import { getCondition } from '../copy-backend-common';
import { getRequest } from '../resources';
import { getClusterOperator } from '../resources/clusteroperator';
import { DELAY_BEFORE_QUERY_RETRY, EMPTY_VIP, MAX_LIVENESS_CHECK_COUNT } from './constants';
import { IpTripletSelectorValidationType, setUIErrorType } from './types';

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

export const waitForLivenessProbe = async (
  counter = MAX_LIVENESS_CHECK_COUNT,
  ztpfwUrl?: string,
) => {
  // This works thanks to the route backup
  ztpfwUrl = ztpfwUrl || getZtpfwUrl();

  try {
    // We can not check new domain for availability due to CORS
    await delay(DELAY_BEFORE_QUERY_RETRY);
    console.info('Checking livenessProbe');
    await getRequest(`${ztpfwUrl}/livenessProbe`).promise;

    return true;
  } catch (e) {
    console.info('ZTPFW UI is not yet ready: ', e);
    if (counter > 0) {
      await waitForLivenessProbe(counter - 1, ztpfwUrl);
    } else {
      console.error('ZTPFW UI did not turn ready, giving up');
      return false;
    }
  }
};

export const waitForClusterOperator = async (
  setError: setUIErrorType,
  name: string,
  waitOnReconciliationStart?: boolean, // Block on starting the reconciliation the operator reconciliation start
): Promise<boolean> => {
  console.info(
    'waitForClusterOperator started for: ',
    name,
    ' . Block on start: ',
    waitForClusterOperator,
  );

  if (waitOnReconciliationStart) {
    try {
      for (let counter = 0; counter < MAX_LIVENESS_CHECK_COUNT; counter++) {
        console.log('Waiting to start, query co: ', name);
        const operator = await getClusterOperator(name).promise;
        if (getCondition(operator, 'Progressing')?.status === 'True') {
          // Started
          console.log('Operator is progressing now: ', name);
          break;
        }
        await delay(DELAY_BEFORE_QUERY_RETRY);
      }
    } catch (e) {
      console.error('waitForClusterOperator error: ', e);
    }
  }

  // Wait on reconciliation end
  for (let counter = 0; counter < MAX_LIVENESS_CHECK_COUNT; counter++) {
    try {
      console.log('Querying co: ', name);
      const operator = await getClusterOperator(name).promise;
      if (
        getCondition(operator, 'Progressing')?.status === 'False' &&
        getCondition(operator, 'Degraded')?.status === 'False' &&
        getCondition(operator, 'Available')?.status === 'True'
      ) {
        // all good
        setError(undefined);
        return true;
      }
    } catch (e) {
      console.error('waitForClusterOperator error: ', e);
      // do not report, keep trying
    }

    await delay(DELAY_BEFORE_QUERY_RETRY);
  }

  setError({
    title: 'Reading operator status failed',
    message: `Failed to query status of ${name} cluster operator on time.`,
  });

  return false;
};
