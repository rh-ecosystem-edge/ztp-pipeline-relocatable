import React from 'react';
import { workaroundUnmarshallObject } from '../test-utils';
import { getResource } from './resource-request';
import { Route } from './Route';

export const useConsoleUrl = () => {
  const [consoleUrl, setConsoleUrl] = React.useState<string>();
  React.useEffect(() => {
    const doItAsync = async () => {
      let route = await getResource<Route>({
        apiVersion: 'route.openshift.io/v1',
        kind: 'Route',
        metadata: {
          name: 'console',
          namespace: 'openshift-console',
        },
      }).promise;

      route = workaroundUnmarshallObject(route);
      const host = route.spec?.host;

      if (host) {
        const result = `https://${host}`;
        console.log('OCP console URL read: ', result);
        setConsoleUrl(result);
      } else {
        console.warn('The OCP console route does not contain host');
      }
    };
    doItAsync();
  }, []);
  return consoleUrl;
};
