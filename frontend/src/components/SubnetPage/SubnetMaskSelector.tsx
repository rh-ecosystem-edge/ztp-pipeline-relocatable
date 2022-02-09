import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector, IpSelectorValidationType } from '../IpSelector';
import { ipAddressValidator } from '../utils';

import './SubnetMaskSelector.css';

export const SubnetMaskSelector: React.FC = () => {
  const [mask, setMask] = React.useState('            ');
  const [validation, setValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });

  const handleSetMask = React.useCallback(
    (newMask: string) => {
      setValidation(ipAddressValidator(newMask, true));
      setMask(newMask);
    },
    [setMask],
  );

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
