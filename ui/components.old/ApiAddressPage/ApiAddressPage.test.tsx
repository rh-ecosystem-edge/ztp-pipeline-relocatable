import React from 'react';
import { render, screen } from '@testing-library/react';

import { ApiAddressPage } from './ApiAddressPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { MemoryRouter } from 'react-router-dom';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <ApiAddressPage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};
describe('ApiAddressPage', () => {
  it('can render', () => {
    const { container } = render(<Component />);
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });
});
