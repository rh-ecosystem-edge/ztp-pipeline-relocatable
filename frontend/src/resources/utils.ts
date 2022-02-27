import React from 'react';
import { getResource } from './resource-request';
import { Route } from './Route';

export const pathJoin = (...args: string[]) => {
  return args
    .map((part, i) => {
      if (i === 0) {
        return part.trim().replace(/[/]*$/g, '');
      } else {
        return part.trim().replace(/(^[/]*|[/]*$)/g, '');
      }
    })
    .filter((x) => x.length)
    .join('/');
};

export const useConsoleUrl = () => {
  const [consoleUrl, setConsoleUrl] = React.useState<string>();
  React.useEffect(() => {
    const doItAsync = async () => {
      const route = await getResource<Route>({
        apiVersion: 'route.openshift.io/v1',
        kind: 'Route',
        metadata: {
          name: 'console',
          namespace: 'openshift-console',
        },
      }).promise;

      if (route.spec?.host) {
        const result = `https://${route.spec.host}`;
        console.log('OCP console URL read: ', result);
        setConsoleUrl(result);
      }
    };
    doItAsync();
  }, []);
  return consoleUrl;
};
