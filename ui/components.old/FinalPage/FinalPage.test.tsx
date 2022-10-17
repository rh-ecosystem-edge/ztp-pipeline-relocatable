import React from 'react';
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { FinalPage } from './FinalPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <FinalPage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};

describe('FinalPage', () => {
  it('can render', async () => {
    const { container } = render(<Component />);
    expect(container).toMatchSnapshot();
  });
});
