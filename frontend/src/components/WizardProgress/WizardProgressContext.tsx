import React from 'react';
import { ProgressStepProps } from '@patternfly/react-core';

type WizardProgressStep = Pick<ProgressStepProps, 'isCurrent' | 'variant'>;

export type WizardProgressSteps = {
  subnet: WizardProgressStep;
  virtualip: WizardProgressStep;
  domain: WizardProgressStep;
  sshkey: WizardProgressStep;
};

export type WizardProgressContextData = {
  steps: WizardProgressSteps;
};

const WizardProgressContext = React.createContext<WizardProgressContextData | null>(null);

export const WizardProgressContextProvider: React.FC<{
  children: React.ReactNode;
  value: WizardProgressContextData;
}> = ({ value, children }) => {
  return <WizardProgressContext.Provider value={value}>{children}</WizardProgressContext.Provider>;
};

export const useWizardProgressContext = () => {
  const context = React.useContext(WizardProgressContext);
  if (!context) {
    throw new Error('useWizardProgressContext must be used within WizardProgressContextProvider.');
  }
  return context;
};
