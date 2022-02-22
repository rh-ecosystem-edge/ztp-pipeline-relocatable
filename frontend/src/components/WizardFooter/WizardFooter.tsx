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

// TODO: add final step
export const WizardFooter: React.FC<WizardFooterProps> = ({ back, next, isNextEnabled }) => {
  const navigate = useNavigate();

  return (
    <div className="wizard-footer">
      <Button variant={ButtonVariant.link} onClick={() => navigate(`/wizard/${back || 'welcome'}`)}>
        Go back
      </Button>
      <Button
        variant={ButtonVariant.primary}
        onClick={() => navigate(`/wizard/${next}`)}
        isDisabled={isNextEnabled && !isNextEnabled()}
      >
        Continue
      </Button>
    </div>
  );
};
