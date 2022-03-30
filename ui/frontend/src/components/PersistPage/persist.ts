import { K8SStateContextData } from '../types';
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
    /* TODO: save domain here */
    (await saveIngress(setError, state.ingressIp)) &&
    /* Persist API at last*/ (await saveApi(setError, state.apiaddr)) &&
    (persistIdpResult !== PersistIdentityProviderResult.userCreated ||
      (await deleteKubeAdmin(setError)))
  ) {
    console.error('TODO: The domain is not persisted.');
    // finished with success

    setError(null); // show the green circle of success
    onSuccess();
  }
};
