import { K8SStateContextData } from '../K8SStateContext';
import { persistIdentityProvider } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PersistErrorType } from './types';

export const persist = async (
  state: K8SStateContextData,
  setError: (error: PersistErrorType) => void,
  onSuccess: () => void,
) => {
  if (
    (await saveIngress(setError, state.ingressIp)) &&
    (await saveApi(setError, state.apiaddr)) &&
    /* TODO: save domain here */
    (await persistIdentityProvider(setError, state.username, state.password))
  ) {
    console.error('TODO: The domain is not persisted.');
    // finished with success

    setError(null); // show the green circle of success
    onSuccess();
  }
};
