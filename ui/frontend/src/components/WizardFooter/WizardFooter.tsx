import React from 'react';
import { Button, ButtonVariant } from '@patternfly/react-core';
import { useNavigate } from 'react-router-dom';

import { WizardStepType } from '../WizardProgress';

import './WizardFooter.css';

export type WizardFooterProps = {
  back?: WizardStepType;
  next: WizardStepType;
  isNextEnabled?: () => boolean;
  onBeforeNext?: () => Promise<boolean>;
};

export const WizardFooter: React.FC<WizardFooterProps> = ({
  back,
  next,
  isNextEnabled,
  onBeforeNext,
}) => {
  const navigate = useNavigate();

  const onNext = async () => {
    if (!onBeforeNext || (await onBeforeNext())) {
      navigate(`/wizard/${next}`);
    }
  };

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
        onClick={onNext}
        isDisabled={isNextEnabled && !isNextEnabled()}
      >
        {next === 'persist' ? 'Finish setup' : 'Continue'}
      </Button>
    </div>
  );
};
