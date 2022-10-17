import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { PasswordPage } from './PasswordPage';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';
import { WizardProgressContextProvider } from '../WizardProgress';

const TestedComponent: React.FC<{
  ctxData?: { password: string };
}> = ({ ctxData }) => {
  const { handleSetPassword } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetPassword(ctxData.password);
    }
  }, [ctxData, handleSetPassword]);

  return <PasswordPage />;
};

const Component: React.FC<{
  ctxData?: { password: string };
}> = ({ ctxData }) => (
  <K8SStateContextProvider>
    <WizardProgressContextProvider>
      <MemoryRouter>
        <TestedComponent ctxData={ctxData} />
      </MemoryRouter>
    </WizardProgressContextProvider>
  </K8SStateContextProvider>
);

describe('PasswordPage', () => {
  it('can render', () => {
    const { container } = render(<Component />);

    expect(screen.queryAllByTestId('requirement-length-failed')).toHaveLength(1);
    expect(screen.queryAllByTestId('requirement-uppercase-failed')).toHaveLength(1);
    expect(screen.queryAllByTestId('password__equality-validation')).toHaveLength(0);
    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();

    expect(container).toMatchSnapshot();
  });

  it('can validate 8 small letters password', () => {
    const { container } = render(<Component ctxData={{ password: 'aaaaaaaa' }} />);

    expect(screen.queryAllByTestId('requirement-length-ok')).toHaveLength(1);
    expect(screen.queryAllByTestId('requirement-uppercase-failed')).toHaveLength(1);
    expect(screen.queryAllByTestId('password__equality-validation')).toHaveLength(1);
    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();

    expect(container).toMatchSnapshot();
  });

  it('can validate 8 small/upper letters password', () => {
    const { container } = render(<Component ctxData={{ password: 'aaaaaaaA' }} />);

    expect(screen.queryAllByTestId('requirement-length-ok')).toHaveLength(1);
    expect(screen.queryAllByTestId('requirement-uppercase-ok')).toHaveLength(1);
    expect(screen.queryAllByTestId('requirement-length-failed')).toHaveLength(0);
    expect(screen.queryAllByTestId('requirement-uppercase-failed')).toHaveLength(0);
    expect(screen.queryAllByTestId('password__equality-validation')).toHaveLength(1);
    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();

    const confirmInput = screen.getByTestId('input-password-check');
    fireEvent.change(confirmInput, { target: { value: 'aaa' } });

    expect(screen.getByTestId('password__equality-validation')).toHaveTextContent(
      'Passwords does not match.',
    );
    expect(screen.getByTestId('wizard-footer-button-next')).toBeDisabled();
    const confirmInput2 = screen.getByTestId('input-password-check');
    fireEvent.change(confirmInput2, { target: { value: 'aaaaaaaA' } });
    expect(screen.queryAllByTestId('password__equality-validation')).toHaveLength(0);
    expect(screen.getByTestId('wizard-footer-button-next')).not.toBeDisabled();

    expect(container).toMatchSnapshot();
  });
});
