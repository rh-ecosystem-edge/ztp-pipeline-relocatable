import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';
import { StaticIPsPanel } from './StaticIPsPanel';

export const StaticIPs: React.FC<{ isEdit: boolean }> = ({ isEdit }) => {
  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Configure your TCP/IP settings for all available hosts</Title>
      </StackItem>
      <StackItem className="wizard-sublabel-dense">
        All control plane nodes must be on a single subnet.
      </StackItem>
      <StackItem className="page-inner-panel__item">
        <StaticIPsPanel isScrollable isEdit={isEdit} />
      </StackItem>
    </Stack>
  );
};
