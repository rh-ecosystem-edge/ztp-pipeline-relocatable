import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { RequiredBadge } from '../Badge';
import { IpTripletsSelector } from '../IpTripletsSelector';
import { useK8SStateContext } from '../K8SStateContext';

import './ApiAddressSelector.css';

export const ApiAddressSelector: React.FC = () => {
  const { apiaddr, handleSetApiaddr, apiaddrValidation: validation } = useK8SStateContext();

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
          <div data-testid="address-validation-failed" className="address-validation-failed">
            {validation.message}
          </div>
        )}
      </StackItem>
    </Stack>
  );
};
