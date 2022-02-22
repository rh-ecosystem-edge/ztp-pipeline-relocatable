import { WizardStateType } from '../Wizard/types';

export type PeristsErrorType = {
  title: string;
  message: string;
} | null;

export const persist = (state: WizardStateType, setError: (error: PeristsErrorType) => void) => {
  setTimeout(() => {
    setError({
      title: 'TODO',
      message: 'Implement persist.ts',
    });
  }, 3000);

  // setTimeout(() => {
  //   setError(null); // finished with success
  // }, 5000);
};
