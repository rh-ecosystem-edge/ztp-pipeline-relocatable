import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { UsernamePage } from './UsernamePage';
import { K8SStateContextProvider } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';

const Component = () => {
  return (
    <K8SStateContextProvider>
      <WizardProgressContextProvider>
        <MemoryRouter>
          <UsernamePage />
        </MemoryRouter>
      </WizardProgressContextProvider>
    </K8SStateContextProvider>
  );
};

describe('UsernamePage', () => {
  it('can render', () => {
    const { container } = render(<Component />);
    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();
    expect(container).toMatchSnapshot();

    const inputField = screen.getByTestId('input-username');
    fireEvent.change(inputField, { target: { value: 'my-user-name' } });
    expect(screen.getByTestId('wizard-footer-button-next')).not.toBeDisabled();
  });
});
