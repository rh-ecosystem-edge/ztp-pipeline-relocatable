import React from 'react';
import { ProgressStepProps } from '@patternfly/react-core';

type WizardProgressStep = Pick<ProgressStepProps, 'isCurrent' | 'variant'>;

// those displayed in the top-level progress
export type WizardProgressStepType =
  | 'username'
  | 'password'
  | 'hostips'
  | 'apiaddr'
  | 'ingressip'
  | 'domain'
  | 'sshkey';

export type WizardStepType =
  | WizardProgressStepType
  | 'persist'
  | 'domaincertsdecision'
  | 'domaincertificates'
  | 'staticips';

export type WizardProgressSteps = {
  username: WizardProgressStep;
  password: WizardProgressStep;
  hostips: WizardProgressStep;
  apiaddr: WizardProgressStep;
  ingressip: WizardProgressStep;
  domain: WizardProgressStep;
  sshkey: WizardProgressStep;
};

export type WizardProgressContextData = {
  steps: WizardProgressSteps;
  setActiveStep: (step: WizardProgressStepType) => void;
};

const WIZARD_STEP_INDEXES: { [key in WizardProgressStepType]: number } = {
  username: 0,
  password: 1,
  hostips: 2,
  apiaddr: 3,
  ingressip: 4,
  domain: 5,
  sshkey: 6,
};

const WizardProgressContext = React.createContext<WizardProgressContextData | null>(null);

export const WizardProgressContextProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
  const [steps, setSteps] = React.useState<WizardProgressSteps>({
    username: {
      isCurrent: true,
      variant: 'info',
    },
    password: {
      isCurrent: false,
      variant: 'pending',
    },
    hostips: {
      isCurrent: false,
      variant: 'pending',
    },
    apiaddr: {
      isCurrent: false,
      variant: 'pending',
    },
    ingressip: {
      isCurrent: false,
      variant: 'pending',
    },
    domain: {
      isCurrent: false,
      variant: 'pending',
    },
    sshkey: {
      isCurrent: false,
      variant: 'pending',
    },
  });

  const value: WizardProgressContextData = React.useMemo(
    () => ({
      steps,

      setActiveStep: (step: WizardProgressStepType) => {
        if (!steps[step].isCurrent) {
          console.log('--- setActiveStep ', step, ', steps: ', steps);
          const newSteps = { ...steps };
          const stepIdx = WIZARD_STEP_INDEXES[step];

          (Object.keys(newSteps) as WizardProgressStepType[]).forEach((key) => {
            newSteps[key].isCurrent = step === key;

            const idx = WIZARD_STEP_INDEXES[key];
            if (idx < stepIdx) {
              newSteps[key].variant = 'success';
            } else if (idx === stepIdx) {
              newSteps[key].variant = 'info';
            } else {
              newSteps[key].variant = 'pending';
            }
          });
          setSteps(newSteps);
        }
      },
    }),
    [steps, setSteps],
  );

  return <WizardProgressContext.Provider value={value}>{children}</WizardProgressContext.Provider>;
};

export const useWizardProgressContext = () => {
  const context = React.useContext(WizardProgressContext);
  if (!context) {
    throw new Error('useWizardProgressContext must be used within WizardProgressContextProvider.');
  }
  return context;
};
