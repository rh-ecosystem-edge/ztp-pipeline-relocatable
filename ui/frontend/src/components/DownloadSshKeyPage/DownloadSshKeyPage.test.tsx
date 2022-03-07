import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { act } from 'react-dom/test-utils';

import { DownloadSshKeyPage } from './DownloadSshKeyPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { delay } from '../../test-utils';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <DownloadSshKeyPage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};

describe('DownloadSshKeyPage', () => {
  beforeEach(() => {
    fetch.resetMocks();
  });

  it('can render', async () => {
    fetch.mockResponseOnce(JSON.stringify({ data: { 'invalid.key': 'aaa' } }));
    let container;
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      container = render(<Component />);
      await delay(1000);
    });

    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();
    expect(screen.getByTestId('wizard-footer-button-next')).toHaveTextContent('Finish setup');
    expect(screen.getByTestId('button-download-ssh-key')).toBeDisabled();
    expect(container).toMatchSnapshot();
  });

  it('can download', async () => {
    // a very simplified stub of a Secret resource...
    fetch.mockResponseOnce(
      JSON.stringify({ data: { 'id_rsa.key': 'aaa' /* Should be Base64 */ } }),
    );
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      render(<Component />);
      await delay(1000);
    });

    expect(fetch).toHaveBeenCalledTimes(1);

    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();
    expect(screen.getByTestId('button-download-ssh-key')).not.toBeDisabled();
    screen.getByTestId('button-download-ssh-key').click();
    expect(screen.getByTestId('wizard-footer-button-next')).not.toBeDisabled();
  });
});
