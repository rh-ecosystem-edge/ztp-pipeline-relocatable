import React from 'react';
import { Page } from '..';
import { ContentTwoRows } from '../ContentTwoRows';
import { getService } from '../../resources/service';
import { WelcomeTop } from './WelcomeTop';

export const WelcomePage: React.FC = () => {
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

  const top = <WelcomeTop />;
  const bottom = <div>BAR</div>;

  return (
    <Page>
      {/* <ContentTwoCols left={left} right={right} /> */}
      <ContentTwoRows top={top} bottom={bottom} />
    </Page>
  );
};
