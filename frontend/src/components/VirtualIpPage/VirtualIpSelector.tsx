import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector } from '../IpSelector';
import { useWizardProgressContext } from '../WizardProgress';

export const VirtualIpSelector: React.FC = () => {
  const {
    state: { ip, handleSetIp, ipValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Virtual IP</Title>
      </StackItem>
      <StackItem>What is your virtual IP address?</StackItem>
      <StackItem>
        <IpSelector address={ip} setAddress={handleSetIp} validation={validation} />
      </StackItem>
      <StackItem isFilled>
        {!validation.valid && (
          <div className="address-validation-failed">Provided IP address is incorrect.</div>
        )}
      </StackItem>
    </Stack>
  );
};
