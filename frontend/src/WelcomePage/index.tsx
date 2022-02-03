import React from 'react';
import { Page } from '../components';
import { getService } from '../resources/service';

const WelcomePage: React.FC = () => {
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

  return <Page>Foo Bar</Page>;
};

export default WelcomePage;
