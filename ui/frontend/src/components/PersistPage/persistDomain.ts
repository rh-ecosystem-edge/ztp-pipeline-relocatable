import { postRequest } from '../../resources';
import { PersistSteps, UsePersistProgressType } from '../PersistProgress';
import { PERSIST_DOMAIN } from './constants';
import { PersistErrorType } from './types';

export const persistDomain = async (
  setError: (error: PersistErrorType) => void,
  setProgress: UsePersistProgressType['setProgress'],
  domain?: string,
): Promise<boolean> => {
  if (!domain) {
    console.info('Domain change not requested, so skipping that step.');
    setProgress(PersistSteps.PersistDomain);
    return true; // skip
  }

  try {
    // Due to complexity, the flow has been moved to backend to decrease risks related to network communication
    await postRequest('/changeDomain', {
      domain,
    }).promise;
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_DOMAIN,
      message: `Failed to change the cluster domain to "${domain}".`,
    });
    return false;
  }

  setProgress(PersistSteps.PersistDomain);
  return true;
};
