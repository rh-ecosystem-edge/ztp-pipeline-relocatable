import React from 'react';
import { render, screen } from '@testing-library/react';

import { DomainPage } from './DomainPage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';
import { MemoryRouter } from 'react-router-dom';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <DomainPage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};
describe('DomainPage', () => {
  it('can render', () => {
    const { container } = render(<Component />);
    expect(screen.getByTestId('wizard-footer-button-next')).not.toBeDisabled();
    expect(container).toMatchSnapshot();
  });
});
