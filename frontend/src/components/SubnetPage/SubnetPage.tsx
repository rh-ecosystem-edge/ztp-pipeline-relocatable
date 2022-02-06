import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';

export const SubnetPage: React.FC = () => {
  return (
    <Page>
      <ContentThreeRows
        top={<div>Top</div>}
        middle={<div>TODO: https://marvelapp.com/prototype/hfd719b/screen/84707949/handoff</div>}
        bottom={<div>bottom</div>}
      />
    </Page>
  );
};
