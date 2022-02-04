import React from 'react';
import { Button, ButtonVariant, Stack, StackItem, Title } from '@patternfly/react-core';

import './WelcomeBottom.css';

export const WelcomeBottom: React.FC = () => (
  <Stack className="welcome-bottom" hasGutter>
    <StackItem>
      <Title headingLevel="h1">KubeFrame</Title>
    </StackItem>
    <StackItem isFilled>To set up the configuration of your KubeFrame, click Continue.</StackItem>
    <StackItem>
      <Button component="a" href="/wizard/subnet" variant={ButtonVariant.primary}>
        Continue
      </Button>
    </StackItem>
  </Stack>
);
