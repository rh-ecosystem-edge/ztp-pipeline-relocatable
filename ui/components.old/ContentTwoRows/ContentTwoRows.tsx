import React from 'react';
import { Stack, StackItem } from '@patternfly/react-core';

import './ContentTwoRows.css';

export const ContentTwoRows: React.FC<{
  top: React.ReactNode;
  bottom: React.ReactNode;
}> = ({ top, bottom }) => (
  <Stack hasGutter>
    <StackItem className="content-two-rows__top">{top}</StackItem>
    <StackItem className="content-two-rows__bottom">{bottom}</StackItem>
  </Stack>
);
