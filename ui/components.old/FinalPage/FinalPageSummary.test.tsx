import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { act } from 'react-dom/test-utils';
import fetch from 'jest-fetch-mock';

import { FinalPageSummary } from './FinalPageSummary';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { delay } from '../../test-utils';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <FinalPageSummary />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};

describe('FinalPageSummary', () => {
  beforeEach(() => {
    fetch.resetMocks();
  });

  it('can render', async () => {
    fetch.mockResponseOnce(JSON.stringify({ spec: { host: 'test-host.com' } }));
    let container;
    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      const { container: c } = render(<Component />);
      container = c;
      await delay(1000);
    });

    expect(fetch).toHaveBeenCalledTimes(1);
    expect(screen.getByTestId('final-page-button-settings')).not.toBeDisabled();
    expect(container).toMatchSnapshot();
  });
});
