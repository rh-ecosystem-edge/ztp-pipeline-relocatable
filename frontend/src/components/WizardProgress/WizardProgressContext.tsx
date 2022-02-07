import React from 'react';
import { ProgressStepProps } from '@patternfly/react-core';

type WizardProgressStep = Pick<ProgressStepProps, 'isCurrent' | 'variant'>;
export type WizardStepType = 'subnet' | 'virtualip' | 'domain' | 'sshkey';

export type WizardProgressSteps = {
  subnet: WizardProgressStep;
  virtualip: WizardProgressStep;
  domain: WizardProgressStep;
  sshkey: WizardProgressStep;
};

export type WizardProgressContextData = {
  steps: WizardProgressSteps;

  setActiveStep: (step: WizardStepType) => void;
};

const WIZARD_STEP_INDEXES: { [key in WizardStepType]: number } = {
  subnet: 0,
  virtualip: 1,
  domain: 2,
  sshkey: 3,
};

const WizardProgressContext = React.createContext<WizardProgressContextData | null>(null);

export const WizardProgressContextProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
  const [steps, setSteps] = React.useState<WizardProgressSteps>({
    subnet: {
      isCurrent: true,
      variant: 'info',
    },
    virtualip: {
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

      setActiveStep: (step: WizardStepType) => {
        if (!steps[step].isCurrent) {
          const newSteps = { ...steps };
          const stepIdx = WIZARD_STEP_INDEXES[step];

          (Object.keys(newSteps) as WizardStepType[]).forEach((key) => {
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
