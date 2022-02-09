import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector } from '../IpSelector';
import { useWizardProgressContext } from '../WizardProgress';

import './SubnetMaskSelector.css';

export const SubnetMaskSelector: React.FC = () => {
  const {
    state: { mask, handleSetMask, maskValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Subnet mask</Title>
      </StackItem>
      <StackItem>What is your subnet mask address?</StackItem>
      <StackItem>
        <IpSelector address={mask} setAddress={handleSetMask} validation={validation} />
      </StackItem>
      <StackItem isFilled>
        {!validation.valid && (
          <div className="address-validation-failed">Provided subnet mask is incorrect.</div>
        )}
      </StackItem>
    </Stack>
  );
};
