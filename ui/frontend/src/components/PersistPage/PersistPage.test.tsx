import React from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { PersistPage } from './PersistPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';

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
  it('can render', () => {
    const { container } = render(<Component />);
    expect(container).toMatchSnapshot();
    // TODO: More complex scenario testing the persist() function on top of mocked data should be implemented
  });
});
