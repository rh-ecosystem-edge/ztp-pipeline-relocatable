import React from 'react';
import { Button, ButtonVariant } from '@patternfly/react-core';
import { useNavigate } from 'react-router-dom';

import { WizardStepType } from '../WizardProgress';

import './WizardFooter.css';

type WizardFooterProps = {
  back?: WizardStepType;
  next: WizardStepType;
  isNextEnabled?: () => boolean;
};

export const WizardFooter: React.FC<WizardFooterProps> = ({ back, next, isNextEnabled }) => {
  const navigate = useNavigate();

  return (
    <div className="wizard-footer">
      <Button
        data-testid="wizard-footer-button-back"
        variant={ButtonVariant.link}
        onClick={() => navigate(`/wizard/${back || 'welcome'}`)}
      >
        Go back
      </Button>
      <Button
        data-testid="wizard-footer-button-next"
        variant={ButtonVariant.primary}
        onClick={() => navigate(`/wizard/${next}`)}
        isDisabled={isNextEnabled && !isNextEnabled()}
      >
        {next === 'persist' ? 'Finish setup' : 'Continue'}
      </Button>
    </div>
  );
};
