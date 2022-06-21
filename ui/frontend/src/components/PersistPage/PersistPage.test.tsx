import React from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { act } from 'react-dom/test-utils';

import { PersistPage } from './PersistPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { delay } from '../../test-utils';

const Component: React.FC = () => (
  <K8SStateContextProvider>
    <WizardProgressContextProvider>
      <MemoryRouter>
        <PersistPage />
      </MemoryRouter>
    </WizardProgressContextProvider>
  </K8SStateContextProvider>
);

describe('PersistPage', () => {
  it('can render', async () => {
    let container;

    // eslint-disable-next-line testing-library/no-unnecessary-act
    await act(async () => {
      const { container: c } = render(<Component />);
      container = c;
      await delay(1000);
    });

    expect(container).toMatchSnapshot();
    // TODO: More complex scenario testing the persist() function on top of mocked data should be implemented
  });
});
