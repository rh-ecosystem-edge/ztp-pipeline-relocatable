import { getApiDomain, getIngressDomain, ValidateDomainAPIResult } from '../../copy-backend-common';
import { postRequest } from '../../resources';

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
