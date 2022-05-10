import React from 'react';
import { Button, ButtonVariant, PageHeaderTools } from '@patternfly/react-core';
import { getBackendUrl, getRequest } from '../../resources';

export const HeaderTools: React.FC = () => {
  const onLogout = async () => {
    const tokenEndpointResult = await getRequest<{ token_endpoint: string }>(
      getBackendUrl() + '/configure',
    ).promise;
    try {
      await getRequest(getBackendUrl() + '/logout').promise;
    } catch (e) {
      console.info('Error received during logout: ', e);
    }

    console.log('Logout, tokenEndpoint: ', tokenEndpointResult);
    const iframe = document.createElement('iframe');
    iframe.setAttribute('type', 'hidden');
    iframe.name = 'hidden-form';
    document.body.appendChild(iframe);

    const form = document.createElement('form');
    form.method = 'POST';
    form.target = 'hidden-form';
    const url = new URL(tokenEndpointResult.token_endpoint);
    form.action = `${url.protocol}//${url.host}/logout`;
    document.body.appendChild(form);

    console.log('Logout: submitting POST request to logout');
    form.submit();

    await new Promise((resolve) => setTimeout(resolve, 500));

    console.info('Logout finished, redirecting to "/"');
    window.location.pathname = '/';
  };

  return (
    <PageHeaderTools>
      <Button component="a" onClick={onLogout} variant={ButtonVariant.tertiary}>
        Log out
      </Button>
    </PageHeaderTools>
  );
};
