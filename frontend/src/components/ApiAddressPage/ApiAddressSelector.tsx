import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';
import { IpTripletsSelector } from '../IpTripletsSelector';

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
        <IpTripletsSelector
          address={apiaddr}
          setAddress={handleSetApiaddr}
          validation={validation}
        />
      </StackItem>
      <StackItem isFilled>
        {validation.message && (
          <div className="address-validation-failed">{validation.message}</div>
        )}
      </StackItem>
    </Stack>
  );
};
