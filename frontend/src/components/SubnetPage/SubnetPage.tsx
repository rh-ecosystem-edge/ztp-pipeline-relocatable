import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';

export const SubnetPage: React.FC = () => {
  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<div>TODO: https://marvelapp.com/prototype/hfd719b/screen/84707949/handoff</div>}
        bottom={<div>bottom</div>}
      />
    </Page>
  );
};
