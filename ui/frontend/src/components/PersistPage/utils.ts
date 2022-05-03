import { getRequest } from '../../resources';
import { DELAY_BEFORE_FINAL_REDIRECT } from './constants';

export const delay = (ms: number) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const waitForLivenessProbe = async (ztpfwUrl: string, counter: number) => {
  try {
    // We can not check new domain for availability due to CORS
    await delay(DELAY_BEFORE_FINAL_REDIRECT);
    console.info('Checking livenessProbe');
    await getRequest(`${ztpfwUrl}/livenessProbe`).promise;

    return true;
  } catch (e) {
    console.info('ZTPFW UI is not yet ready: ', e);
    if (counter > 0) {
      await waitForLivenessProbe(ztpfwUrl, counter - 1);
    } else {
      console.error('ZTPFW UI did not turn ready, giving up');
      return false;
    }
  }
};
