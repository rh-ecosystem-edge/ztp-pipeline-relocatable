import { postRequest } from '../../resources';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';
import { PERSIST_DOMAIN } from './constants';
import { PersistErrorType } from './types';
import { ChangeDomainInputType } from '../../backend-shared';

export const persistDomain = async (
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  clusterDomain?: string,
  customCerts?: ChangeDomainInputType['customCerts'],
): Promise<boolean> => {
  if (!clusterDomain) {
    console.info('Domain change not requested, so skipping that step.');
    setProgress(PersistSteps.PersistDomain);
    return true; // skip
  }

  const input: ChangeDomainInputType = {
    clusterDomain,
    customCerts,
  };

  try {
    // Due to complexity, the flow has been moved to backend to decrease risks related to network communication
    await postRequest('/changeDomain', input).promise;
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_DOMAIN,
      message: `Failed to change the cluster domain to "${clusterDomain}".`,
    });
    return false;
  }

  setProgress(PersistSteps.PersistDomain);
  return true;
};
