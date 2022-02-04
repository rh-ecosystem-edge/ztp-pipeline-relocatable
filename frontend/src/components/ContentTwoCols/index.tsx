import React from 'react';
import { Grid, GridItem } from '@patternfly/react-core';

export const ContentTwoCols: React.FC<{
  left: React.ReactNode;
  right: React.ReactNode;
}> = ({ left, right }) => (
  <Grid hasGutter>
    <GridItem span={6}>{left}</GridItem>
    <GridItem span={6}>{right}</GridItem>
  </Grid>
);
