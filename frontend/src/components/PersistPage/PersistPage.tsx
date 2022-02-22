import React from 'react';

import { Page } from '../Page';
import { ContentTwoRows } from '../ContentTwoRows';

import { WelcomeTop } from '../WelcomePage/WelcomeTop';
import { PersistPageBottom } from './PersistPageBottom';

export const PersistPage: React.FC = () => {
  return (
    <Page>
      <ContentTwoRows top={<WelcomeTop />} bottom={<PersistPageBottom />} />
    </Page>
  );
};
