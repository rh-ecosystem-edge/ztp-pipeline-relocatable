import { WizardStateType } from '../Wizard/types';
import { saveApi, saveIngress } from './persistServices';
import { PeristsErrorType } from './types';

export const persist = async (
  state: WizardStateType,
  setError: (error: PeristsErrorType) => void,
) => {
  if ((await saveIngress(setError, state.ingressIp)) && (await saveApi(setError, state.apiaddr))) {
    setError(null); // finished with success
  }
};
