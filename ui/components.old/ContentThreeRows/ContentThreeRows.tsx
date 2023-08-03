import React from 'react';
import { Stack, StackItem } from '@patternfly/react-core';

import './ContentThreeRows.css';

export const ContentThreeRows: React.FC<{
  top: React.ReactNode;
  middle: React.ReactNode;
  bottom: React.ReactNode;
}> = ({ top, middle, bottom }) => (
  <Stack hasGutter>
    <StackItem className="content-three-rows__top">{top}</StackItem>
    <StackItem isFilled className="content-three-rows__middle">
      {middle}
    </StackItem>
    <StackItem className="content-three-rows__bottom">{bottom}</StackItem>
  </Stack>
);
