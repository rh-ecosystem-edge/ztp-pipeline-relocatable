import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';

import { IpSelector } from '../IpSelector';

export const VirtualIpSelector: React.FC = () => {
  const [ip, setIp] = React.useState('            ');

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Virtual IP</Title>
      </StackItem>
      <StackItem>What is your virtual IP address?</StackItem>
      <StackItem isFilled>
        <IpSelector address={ip} setAddress={setIp} />
      </StackItem>
    </Stack>
  );
};
