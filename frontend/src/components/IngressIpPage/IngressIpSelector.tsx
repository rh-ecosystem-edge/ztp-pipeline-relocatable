import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';
import { IpTripletsSelector } from '../IpTripletsSelector';

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
      <StackItem className="wizard-sublabel">
        Assign the IP address that will be used for new routes and traffic managed by the ingress
        controller.
      </StackItem>
      <StackItem>
        <IpTripletsSelector
          address={ingressIp}
          setAddress={handleSetIngressIp}
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
