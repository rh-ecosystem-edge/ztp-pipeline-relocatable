import { ChangeStaticIpsInputType, HostInterfaceType, HostType } from '../../copy-backend-common';
import { postRequest } from '../../resources';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';
import { delay } from '../utils';
import { DELAY_BEFORE_FINAL_REDIRECT, PERSIST_STATIC_IPS } from './constants';

import { PersistErrorType } from './types';
import { waitForClusterOperator } from './utils';

export const persistStaticIPs = async (
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  hosts?: HostType[],
) => {
  if (!hosts?.length) {
    console.info('Setting of host static IPs is not requested, so skipping that step.');
    setProgress(PersistSteps.ReconcilePersistStaticIPs);
    return true; // skip
  }

  const input: ChangeStaticIpsInputType = {
    hosts: hosts.map(
      // Reduce the data to valid ones only
      (h): HostType => ({
        hostname: h.hostname,
        nodeName: h.nodeName,
        nncpName: h.nncpName,

        dns: h.dns,

        interfaces: h.interfaces.map(
          (i): HostInterfaceType => ({
            name: i.name,
            ipv4: {
              address: {
                ip: i.ipv4.address?.ip,
                prefixLength: i.ipv4.address?.prefixLength,
                gateway: i.ipv4.address?.gateway,
              },
            },
          }),
        ),
      }),
    ),
  };

  try {
    // Due to complexity, the flow has been moved to backend to decrease risks related to network communication
    await postRequest('/setStaticIPs', input).promise;
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_STATIC_IPS,
      message: `Failed to change static IPs of the hosts.`,
    });
    return false;
  }

  setProgress(PersistSteps.PersistStaticIPs);

  console.log('Static IPs persisted, blocking progress till reconciled.');
  // Let the operator reconciliation start
  await delay(DELAY_BEFORE_FINAL_REDIRECT);

  // TODO: CHANGE FOLLOWING!!! Watch nodenetworkstates for changes
  if (!(await waitForClusterOperator(setError, 'authentication'))) {
    return false;
  }

  setProgress(PersistSteps.ReconcilePersistStaticIPs);

  return true;
};
