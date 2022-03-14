import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';

import { ApiAddressSelector } from './ApiAddressSelector';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';

const TestedComponent: React.FC<{
  ctxData?: { apiaddr: string /* apiaddrValidation: IpTripletSelectorValidationType*/ };
}> = ({ ctxData }) => {
  const { handleSetApiaddr } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetApiaddr(ctxData.apiaddr);
    }
  }, [ctxData, handleSetApiaddr]);

  return <ApiAddressSelector />;
};

const Component: React.FC<{
  ctxData?: { apiaddr: string };
}> = ({ ctxData }) => (
  <K8SStateContextProvider>
    <TestedComponent ctxData={ctxData} />
  </K8SStateContextProvider>
);

describe('ApiAddressSelector', () => {
  it('can render', () => {
    const { container } = render(<Component />);

    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });

  it('can render non-default IP', () => {
    const { container } = render(<Component ctxData={{ apiaddr: '123 86111  2' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('123');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('86');
    expect(screen.getByTestId('ip-triplet-3')).toHaveValue('2');
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);

    expect(container).toMatchSnapshot();
  });

  it('can render validation error', () => {
    const { container } = render(<Component ctxData={{ apiaddr: '123586111  2' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('123');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('586');
    expect(screen.getByTestId('ip-triplet-3')).toHaveValue('2');

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
    const { container } = render(<Component ctxData={{ apiaddr: '123 86111  2' }} />);

    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('123');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('86');
    expect(screen.getByTestId('ip-triplet-3')).toHaveValue('2');

    const triplet0 = screen.getByTestId('ip-triplet-0');
    fireEvent.change(triplet0, { target: { value: '222' } });

    // chnage to correct value
    expect(screen.getByTestId('ip-triplet-0')).toHaveValue('222');
    expect(screen.getByTestId('ip-triplet-1')).toHaveValue('86');
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);

    // try to change to wrong value
    const triplet2 = screen.getByTestId('ip-triplet-2');
    fireEvent.change(triplet2, { target: { value: '555' } });
    // the value stays - component does not pass the wrong value
    expect(screen.getByTestId('ip-triplet-2')).toHaveValue('111');
    expect(screen.queryAllByTestId('address-validation-failed')).toHaveLength(0);

    expect(container).toMatchSnapshot();
  });
});
