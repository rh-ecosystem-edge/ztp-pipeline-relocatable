import React from 'react';

import { Page } from '../Page';
import { ContentTwoRows } from '../ContentTwoRows';
import { getService } from '../../resources/service';

import { WelcomeTop } from './WelcomeTop';
import { WelcomeBottom } from './WelcomeBottom';

export const WelcomePage: React.FC = () => {
  // TODO: remove following, so far to force login; replace by loading date for Edit
  React.useEffect(() => {
    const doItAsync = async () => {
      const service = await getService({
        name: 'router-internal-default',
        namespace: 'openshift-ingress',
      }).promise;
      console.log('--- Service: ', service);
    };

    doItAsync();
  }, []);

  return (
    <Page>
      {/* <ContentTwoCols left={left} right={right} /> */}
      <ContentTwoRows top={<WelcomeTop />} bottom={<WelcomeBottom />} />
    </Page>
  );
};
