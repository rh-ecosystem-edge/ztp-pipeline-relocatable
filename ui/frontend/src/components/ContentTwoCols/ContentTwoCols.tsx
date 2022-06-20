import React from 'react';
import { Grid, GridItem, gridSpans } from '@patternfly/react-core';

import './ContentTwoCols.css';

export const ContentTwoCols: React.FC<{
  left: React.ReactNode;
  right: React.ReactNode;
  spanLeft?: gridSpans;
  spanRight?: gridSpans;
}> = ({ left, right, spanLeft = 6, spanRight = 6 }) => (
  <Grid hasGutter className="content-two-cols">
    <GridItem span={spanLeft}>{left}</GridItem>
    <GridItem span={spanRight}>{right}</GridItem>
  </Grid>
);
