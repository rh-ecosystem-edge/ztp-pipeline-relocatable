import React from 'react';
import { render, screen } from '@testing-library/react';
import { act } from 'react-dom/test-utils';
import { MemoryRouter } from 'react-router-dom';
import fetch from 'jest-fetch-mock';

import { WelcomePage } from './WelcomePage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { delay } from '../../test-utils';
import { IDENTITY_PROVIDER_NAME } from '../PersistPage/constants';

const mockedUsedNavigate = jest.fn();
jest.mock('react-router-dom', () => ({
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ...(jest.requireActual('react-router-dom') as any),
  useNavigate: () => mockedUsedNavigate,
}));

const Component: React.FC = () => (
  <K8SStateContextProvider>
    <WizardProgressContextProvider>
      <MemoryRouter>
        <WelcomePage />
      </MemoryRouter>
    </WizardProgressContextProvider>
  </K8SStateContextProvider>
);

describe('Settings', () => {
  beforeEach(() => {
    fetch.resetMocks();
  });

  it('can render', async () => {
    let container;
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      const { container: c } = render(<Component />);
      container = c;
      await delay(1000);
    });
    expect(fetch).toHaveBeenCalledTimes(4);

    expect(screen.getByTestId('welcome-button-continue')).not.toBeDisabled();
    expect(container).toMatchSnapshot();
  });

  it('can render wizard', async () => {
    fetch
      .once(JSON.stringify({ spec: {} })) /* OAuth */
      .once(JSON.stringify({ spec: { loadBalancerIP: undefined } }) /* ingress service */)
      .once(JSON.stringify({ spec: { loadBalancerIP: '123.1.2.3' } }) /* api service */)
      .once(JSON.stringify({ spec: { domain: 'apps.test.domain.com' } }) /* Ingress resource */);

    let container;
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      const { container: c } = render(<Component />);
      container = c;
      await delay(1000);
    });
    expect(fetch).toHaveBeenCalledTimes(4);
    expect(container).toMatchSnapshot();
    expect(screen.getByTestId('welcome-button-continue')).not.toBeDisabled();
    screen.getByTestId('welcome-button-continue').click();
    expect(mockedUsedNavigate).toHaveBeenCalledTimes(1);
    expect(mockedUsedNavigate.mock.calls[0][0]).toBe('/wizard/username');
  });

  it('can render Settings page', async () => {
    expect(mockedUsedNavigate).toHaveBeenCalledTimes(0);
    fetch
      .once(
        JSON.stringify({
          spec: {
            identityProviders: [
              {
                name: IDENTITY_PROVIDER_NAME,
                mappingMethod: 'claim',
                type: 'HTPasswd',
                htpasswd: {
                  fileData: {
                    name: 'a-file-name',
                  },
                },
              },
            ],
          },
        }),
      )
      .once(JSON.stringify({ spec: { loadBalancerIP: undefined } }) /* ingress service */)
      .once(JSON.stringify({ spec: { loadBalancerIP: '123.1.2.3' } }) /* api service */)
      .once(JSON.stringify({ spec: { domain: 'apps.test.domain.com' } }) /* Ingress resource */);

    let container;
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      const { container: c } = render(<Component />);
      container = c;
      await delay(1000);
    });
    expect(fetch).toHaveBeenCalledTimes(4);
    expect(container).toMatchSnapshot();
    expect(screen.getByTestId('welcome-button-continue')).not.toBeDisabled();
    screen.getByTestId('welcome-button-continue').click();
    expect(mockedUsedNavigate).toHaveBeenCalledTimes(1);
    expect(mockedUsedNavigate.mock.calls[0][0]).toBe('/settings');
  });
});
