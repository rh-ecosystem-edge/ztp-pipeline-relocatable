import { WizardStateType } from '../Wizard/types';
import { persistIdentityProvider } from './persistIdentityProvider';
import { saveApi, saveIngress } from './persistServices';
import { PeristsErrorType } from './types';

export const persist = async (
  state: WizardStateType,
  setError: (error: PeristsErrorType) => void,
  onSuccess: () => void,
) => {
  if (
    (await saveIngress(setError, state.ingressIp)) &&
    (await saveApi(setError, state.apiaddr)) &&
    (await persistIdentityProvider(setError, state.username, state.password))
  ) {
    // finished with success

    setError(null); // show green circle of success
    onSuccess();
  }
};
