import React from 'react';

import { Page } from '../Page';
import { ContentTwoCols } from '../ContentTwoCols';
import { FinalPageLeft } from './FinalPageLeft';
import { FinalPageSummary } from './FinalPageSummary';

export const FinalPage: React.FC = () => {
  return (
    <Page>
      <ContentTwoCols left={<FinalPageLeft />} right={<FinalPageSummary />} />
    </Page>
  );
};
