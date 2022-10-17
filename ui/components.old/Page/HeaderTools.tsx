import React from 'react';
import { Button, ButtonVariant, PageHeaderTools } from '@patternfly/react-core';
import { getBackendUrl, getRequest } from '../../resources';
import { getAuthorizationEndpointUrl } from '../utils';
import { isKubeAdmin } from '../../resources/oauth';

export const HeaderTools: React.FC = () => {
  const onLogout = async () => {
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

    // Following is needed for kubeadmin only
    if (kubeadmin) {
      // We need to remove the 'ssn' cookie for https://oauth-openshift.[CLUSTER_INGRESS_DOMAIN]

      // Since it is cross-origin request, we use a hidden form
      const form = document.createElement('form');
      form.method = 'POST';

      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'then';
      // The /logout oauth endpoint will redirect (HTTP 302) here
      input.value = getAuthorizationEndpointUrl();
      console.log('After successful logout, the flow will continue here: ', input.value);

      form.appendChild(input);

      const url = new URL(tokenEndpointResult.token_endpoint);
      const actionUrl = `${url.protocol}//${url.host}/logout`;
      form.action = actionUrl;
      document.body.appendChild(form);

      console.log('About to submit POST: ', actionUrl);
      form.submit();
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
