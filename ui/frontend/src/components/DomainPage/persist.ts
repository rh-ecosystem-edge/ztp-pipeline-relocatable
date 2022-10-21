import { postRequest } from '../../resources';
import {
  ChangeDomainInputType,
  ValidateDomainAPIResult,
  getIngressDomain,
  getApiDomain,
} from '../../backend-shared';
import { setUIErrorType } from '../types';
import { waitForClusterOperator } from '../utils';

export const persistDomain = async (
  setError: setUIErrorType,
  clusterDomain?: string,
  customCerts?: ChangeDomainInputType['customCerts'],
): Promise<boolean> => {
  if (!clusterDomain) {
    console.info('Domain change not requested, so skipping that step.');
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
      title: 'Changing domain failed',
      message: `Failed to change the cluster domain to "${clusterDomain}".`,
    });
    return false;
  }

  console.log('Domain persisted, blocking progress till reconciled.');
  // Let the operator reconciliation start
  if (!(await waitForClusterOperator(setError, 'authentication', true))) {
    return false;
  }

  return true;
};

export const validateDomainBackend = async (
  onError: (message: string) => void,
  domain: string,
): Promise<boolean> => {
  try {
    const result = (await postRequest('/validateDomain', {
      domain,
    }).promise) as ValidateDomainAPIResult;
    if (!result?.result) {
      onError(
        `Provided domain can not be resolved. Make sure your nameserver is properly set to resolve all subdomains (i.e. ${getApiDomain(
          domain,
        )} or ${getIngressDomain(domain)})`,
      );
      return false;
    }

    // success
    return true;
  } catch (e) {
    console.error(e);
    onError('Failed to validate the domain (internal error).');
  }

  return false;
};
