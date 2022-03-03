import React from 'react';
import { render, screen } from '@testing-library/react';

import { IngressIpPage } from './IngressIpPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { MemoryRouter } from 'react-router-dom';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <IngressIpPage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};
describe('IngressIpPage', () => {
  it('can render', () => {
    const { container } = render(<Component />);
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });
});
