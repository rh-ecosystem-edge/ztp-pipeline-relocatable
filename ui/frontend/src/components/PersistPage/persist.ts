import { K8SStateContextData } from '../types';
import { persistIdentityProvider } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  onSuccess: () => void,
) => {
  if (
    (await persistIdentityProvider(setError, state.username, state.password)) &&
    /* TODO: save domain here */
    (await saveIngress(setError, state.ingressIp)) &&
    /* Persist API at last*/ (await saveApi(setError, state.apiaddr))
  ) {
    console.error('TODO: The domain is not persisted.');
    // finished with success

    setError(null); // show the green circle of success
    onSuccess();
  }
};
