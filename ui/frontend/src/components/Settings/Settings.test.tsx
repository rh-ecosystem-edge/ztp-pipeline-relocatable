import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { SettingsContent, SettingsLoading } from './Settings';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';
import { ipWithoutDots } from '../utils';

type CTX_TYPE = {
  ctxData?: { apiaddr: string; ingressIp: string; domain: string };
  error?: string;
};

const TestedComponent: React.FC<CTX_TYPE> = ({ ctxData, error }) => {
  const { handleSetApiaddr, handleSetIngressIp, handleSetDomain } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetApiaddr(ctxData.apiaddr);
      handleSetIngressIp(ctxData.ingressIp);
      handleSetDomain(ctxData.domain);
    }
  }, [ctxData, handleSetApiaddr, handleSetDomain, handleSetIngressIp]);

  return <SettingsContent error={error} forceReload={jest.fn()} />;
};

const Component: React.FC<CTX_TYPE> = (props) => (
  <K8SStateContextProvider>
    <MemoryRouter>
      <TestedComponent {...props} />
    </MemoryRouter>
  </K8SStateContextProvider>
);

describe('Seetings', () => {
  it('can render loading state', () => {
    const { container } = render(<SettingsLoading />);
    expect(container).toMatchSnapshot();
  });

  it('can render error', () => {
    const { container } = render(<Component error="My error to test" />);
    expect(screen.getByTestId('settings-page-alert-error')).toHaveTextContent('My error to test');
    expect(screen.queryAllByTestId('settings-page-alert-all-saved')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });

  it('can render data', () => {
    const { container } = render(
      <Component
        ctxData={{
          apiaddr: ipWithoutDots('192.168.1.2'),
          ingressIp: ipWithoutDots('1.5.22.255'),
          domain: 'my.domain.com',
        }}
      />,
    );
    expect(screen.queryAllByTestId('settings-page-alert-all-saved')).toHaveLength(0);
    expect(screen.queryAllByTestId('settings-page-alert-all-error')).toHaveLength(0);
    expect(screen.getByTestId('ingress-ip')).toHaveValue('1.5.22.255');
    expect(screen.getByTestId('ingress-ip')).toBeDisabled();
    expect(screen.getAllByTestId('ingress-ip')).toHaveLength(1);
    expect(container).toMatchSnapshot();

    screen.getByTestId('settings-page-button-edit').click();
    expect(screen.getByTestId('settings-page-input-domain')).not.toBeDisabled();
    expect(screen.getByTestId('settings-page-input-domain')).toHaveValue('my.domain.com');
    expect(screen.getByTestId('ingress-ip-1')).toHaveValue('5');
    expect(screen.getByTestId('ingress-ip-1')).not.toBeDisabled();
    expect(screen.getByTestId('ingress-ip-2')).toHaveValue('22');
    expect(screen.getByTestId('ingress-ip-2')).not.toBeDisabled();
    expect(screen.getByTestId('ingress-ip-3')).toHaveValue('255');
    expect(screen.getByTestId('ingress-ip-3')).not.toBeDisabled();
    expect(screen.queryAllByTestId('ingress-ip')).toHaveLength(0);
    expect(container).toMatchSnapshot();

    screen.getByTestId('settings-page-button-cancel').click();
    expect(screen.getAllByTestId('ingress-ip')).toHaveLength(1);
    expect(screen.queryAllByTestId('ingress-ip-3')).toHaveLength(0);
    expect(screen.getByTestId('apiaddr')).toHaveValue('192.168.1.2');
    expect(screen.getByTestId('apiaddr')).toBeDisabled();
    expect(container).toMatchSnapshot();
  });
});
