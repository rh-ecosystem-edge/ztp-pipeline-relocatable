import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector } from '../IpSelector';
import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';

export const IngressIpSelector: React.FC = () => {
  const {
    state: { ingressIp, handleSetIngressIp, ingressIpValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          What's your ingress address? <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem>
        Assign the IP address that will be used for new routes and traffic managed by the ingress
        controller.
      </StackItem>
      <StackItem>
        <IpSelector address={ingressIp} setAddress={handleSetIngressIp} validation={validation} />
      </StackItem>
      <StackItem isFilled>
        {!validation.valid && (
          <div className="address-validation-failed">Provided IP address is incorrect.</div>
        )}
      </StackItem>
    </Stack>
  );
};
