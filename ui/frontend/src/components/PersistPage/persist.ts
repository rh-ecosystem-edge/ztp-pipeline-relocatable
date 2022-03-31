import { K8SStateContextData } from '../types';
import { persistDomain } from './persistDomain';
import {
  deleteKubeAdmin,
  persistIdentityProvider,
  PersistIdentityProviderResult,
} from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  onSuccess: () => void,
) => {
  const persistIdpResult = await persistIdentityProvider(setError, state.username, state.password);
  if (
    persistIdpResult !== PersistIdentityProviderResult.error &&
    (await saveIngress(setError, state.ingressIp)) &&
    (await persistDomain(setError, state.domain)) &&
    (persistIdpResult !== PersistIdentityProviderResult.userCreated ||
      (await deleteKubeAdmin(setError))) &&
    (await saveApi(setError, state.apiaddr))
  ) {
    // finished with success
    setError(null); // show the green circle of success
    onSuccess();
  }
};
