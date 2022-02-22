import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector } from '../IpSelector';
import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';

import './ApiAddressSelector.css';

export const ApiAddressSelector: React.FC = () => {
  const {
    state: { apiaddr, handleSetApiaddr, apiaddrValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          What is your API address? <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Assign the IP address that will be used for API traffic.
      </StackItem>
      <StackItem>
        <IpSelector address={apiaddr} setAddress={handleSetApiaddr} validation={validation} />
      </StackItem>
      <StackItem isFilled>
        {!validation.valid && (
          <div className="address-validation-failed">Provided subnet mask is incorrect.</div>
        )}
      </StackItem>
    </Stack>
  );
};
