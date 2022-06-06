import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';
import { AutomaticManualDecision, AutomaticManualDecisionProps } from '../AutomaticManualDecision';
import { RequiredBadge } from '../Badge';

export const HostIPDecision: React.FC<AutomaticManualDecisionProps> = (props) => {
  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          How do you want to configure IPv4? <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Choose whether you want to automatically assign IP addresses for hosts of the cluster.
      </StackItem>
      <StackItem>
        <AutomaticManualDecision
          labelAutomatic="Automatic (DHCP)"
          labelManual="Manual (Static)"
          {...props}
        />
      </StackItem>
    </Stack>
  );
};
