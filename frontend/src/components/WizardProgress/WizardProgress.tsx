import React from 'react';
import { ProgressStepper, ProgressStep } from '@patternfly/react-core';

import { useWizardProgressContext } from './WizardProgressContext';

import './WizardProgress.css';

export const WizardProgress: React.FC = () => {
  const { steps } = useWizardProgressContext();

  return (
    <ProgressStepper isCenterAligned className="wizard-progress">
      <ProgressStep
        // description=""
        id="subnet"
        titleId="subnet-title"
        aria-label="Subnet step"
        {...steps.subnet}
      >
        Subnet
      </ProgressStep>
      <ProgressStep
        id="virtualip"
        titleId="virtualip-title"
        aria-label="Virtual IP step"
        {...steps.virtualip}
      >
        Virtual IP
      </ProgressStep>
      <ProgressStep id="domain" titleId="domain-title" aria-label="Domain step" {...steps.domain}>
        Domain
      </ProgressStep>
      <ProgressStep id="sshkey" titleId="sshkey-title" aria-label="Ssh key step" {...steps.sshkey}>
        SSH key
      </ProgressStep>
    </ProgressStepper>
  );
};
