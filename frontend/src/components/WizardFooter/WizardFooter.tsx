import React from 'react';
import { Button, ButtonVariant } from '@patternfly/react-core';

import { WizardStepType } from '../WizardProgress';

import './WizardFooter.css';

type WizardFooterProps = {
  back?: WizardStepType;
  next: WizardStepType;
};

// TODO: add final step
export const WizardFooter: React.FC<WizardFooterProps> = ({ back, next }) => (
  <div className="wizard-footer">
    <Button component="a" href={`/wizard/${back || 'welcome'}`} variant={ButtonVariant.link}>
      Go back
    </Button>
    <Button component="a" href={`/wizard/${next}`} variant={ButtonVariant.primary}>
      Continue
    </Button>
  </div>
);
