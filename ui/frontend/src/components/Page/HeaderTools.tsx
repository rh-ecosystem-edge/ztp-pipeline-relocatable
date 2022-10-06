import React from 'react';
import { Button, ButtonVariant, PageHeaderTools } from '@patternfly/react-core';
import { getBackendUrl, getRequest } from '../../resources';
import { persistIdentityProvider } from '../PersistPage/persistIdentityProvider';
import { isKubeAdmin } from '../utils';

export const HeaderTools: React.FC = () => {
  const onLogout = async () => {
    // DO NOT MERGE:
    await persistIdentityProvider(
      (error) => {
        console.log('----- persistIdentityProvider error: ', error);
      },
      (step) => {
        console.log('---- persistIdentityProvider step: ', step);
      },
      'user',
      'pwd',
    );

    // call that before we delete oauthaccesstoken
    const kubeadmin = await isKubeAdmin();

    const tokenEndpointResult = await getRequest<{ token_endpoint: string }>(
      getBackendUrl() + '/configure',
    ).promise;
    console.log('tokenEndpointResult: ', tokenEndpointResult);

    try {
      await getRequest(getBackendUrl() + '/logout').promise;
    } catch (e) {
      console.info('Error received during logout: ', e);
    }
    console.log('ZTPFW logout finished, revoke oauth session now');

    // Following is needed for kubeadmin only
    if (kubeadmin) {
      // We need to remove the 'ssn' cookie for https://oauth-openshift.[CLUSTER_INGRESS_DOMAIN]

      // const iframe = document.createElement('iframe');
      // iframe.setAttribute('type', 'hidden');
      // iframe.setAttribute('height', '0');
      // iframe.setAttribute('width', '0');
      // iframe.name = 'hidden-form';
      // document.body.appendChild(iframe);

      // Since it is cross-origin request, we use a hidden form
      const form = document.createElement('form');
      form.method = 'POST';
      // form.target = 'hidden-form';

      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'then';
      // The /logout oauth endpoint will redirect (HTTP 302) here
      input.value = `${window.location.origin}/`;
      // But:
      //   works:  'https://console-openshift-console.apps.ci-ln-pt8nxpt-76ef8.aws-2.ci.openshift.org/';
      //   does not redirect:   https://edge-cluster-setup.apps.ci-ln-pt8nxpt-76ef8.aws-2.ci.openshift.org/
      form.appendChild(input);

      const url = new URL(tokenEndpointResult.token_endpoint);
      const actionUrl = `${url.protocol}//${url.host}/logout`;
      form.action = actionUrl;
      document.body.appendChild(form);

      console.log('About to submitt POST: ', actionUrl);
      form.submit();
      console.log('Submitted');
      return;
    }

    await new Promise((resolve) => setTimeout(resolve, 500));

    console.info('Logout finished, redirecting to "/welcome"');
    window.location.pathname = '/welcome';
  };

  return (
    <PageHeaderTools>
      <Button component="a" onClick={onLogout} variant={ButtonVariant.tertiary}>
        Log out
      </Button>
    </PageHeaderTools>
  );
};
