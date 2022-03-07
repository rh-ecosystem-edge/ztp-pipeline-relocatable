import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';

import { IngressIpSelector } from './IngressIpSelector';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';

const TestedComponent: React.FC<{
  ctxData?: { ingressIp: string };
}> = ({ ctxData }) => {
  const { handleSetIngressIp } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetIngressIp(ctxData.ingressIp);
    }
  }, [ctxData, handleSetIngressIp]);

  return <IngressIpSelector />;
};

const Component: React.FC<{
  ctxData?: { ingressIp: string };
}> = ({ ctxData }) => (
  <K8SStateContextProvider>
    <TestedComponent ctxData={ctxData} />
  </K8SStateContextProvider>
);

describe('IngressIpSelector', () => {
  it('can render', () => {
    const { container } = render(<Component />);

    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });

  it('can render non-default IP', () => {
    const { container } = render(<Component ctxData={{ ingressIp: '012221255 10' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('012');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('221');
    expect(screen.getByTestId('ip-triplet-3')).toHaveValue('010');
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);

    expect(container).toMatchSnapshot();
  });

  it('can render validation error', async () => {
    const { container } = render(<Component ctxData={{ ingressIp: '123586111  2' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('123');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('586');
    expect(screen.getByTestId('ip-triplet-3')).toHaveValue('002');

    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(1);
    expect(screen.getByTestId('address-validation-failed')).toHaveClass(
      'address-validation-failed',
    );
    expect(screen.getByTestId('address-validation-failed')).toContainHTML(
      'Provided IP address is incorrect.',
    );

    expect(container).toMatchSnapshot();
  });

  it('can render change value', () => {
    const { container } = render(<Component ctxData={{ ingressIp: '012221255 10' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('012');

    const triplet0 = screen.getByTestId('ip-triplet-0');
    fireEvent.change(triplet0, { target: { value: '222' } });

    // chnage to correct value
    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('222');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('221');
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);

    expect(container).toMatchSnapshot();
  });
});
