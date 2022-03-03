import React from 'react';
import { Stack, StackItem, Spinner as PFSpinner } from '@patternfly/react-core';

export const Spinner = () => (
  <Stack>
    <StackItem>
      <PFSpinner isSVG size="xl" />
    </StackItem>
  </Stack>
);
