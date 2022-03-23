import { postRequest } from '../../resources';
import { PERSIST_DOMAIN } from './constants';
import { PersistErrorType } from './types';

// Due to complexity, the flow has been moved to backend to decrease risks related to network communication
export const persistDomain = async (
  setError: (error: PersistErrorType) => void,
  domain?: string,
): Promise<boolean> => {
  if (!domain) {
    console.info('Domain change not requested, so skipping that step.');
    return true; // skip
  }

  try {
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

  return true;
};
