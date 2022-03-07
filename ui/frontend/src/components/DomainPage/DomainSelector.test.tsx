import React from 'react';
import { render, screen } from '@testing-library/react';

import { DomainSelector } from './DomainSelector';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';

const TestedComponent: React.FC<{
  ctxData?: { domain: string };
}> = ({ ctxData }) => {
  const { handleSetDomain } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetDomain(ctxData.domain);
    }
  }, [ctxData, handleSetDomain]);

  return <DomainSelector />;
};

const Component: React.FC<{
  ctxData?: { domain: string };
}> = ({ ctxData }) => (
  <K8SStateContextProvider>
    <TestedComponent ctxData={ctxData} />
  </K8SStateContextProvider>
);

describe('DomainSelector', () => {
  it('can render', () => {
    const { container } = render(<Component />);

    expect(screen.queryAllByTestId('domain-validation-failed')).toHaveLength(0);
    expect(screen.getByTestId('domain-selector-example-setup')).toHaveClass(
      'domain-selector__example-domain',
    );
    expect(screen.getByTestId('domain-selector-example-console')).toHaveClass(
      'domain-selector__example-domain',
    );
    expect(container).toMatchSnapshot();
  });

  it('can can handle invalid domain', () => {
    const { container } = render(<Component ctxData={{ domain: 'invalid' }} />);

    expect(screen.queryAllByTestId('domain-validation-failed')).toHaveLength(1);
    expect(screen.getByTestId('domain-selector-example-setup')).toHaveTextContent('invalid');
    expect(screen.getByTestId('domain-selector-example-setup')).toHaveClass(
      'domain-selector__example-domain-invalid',
    );
    expect(screen.getByTestId('domain-selector-example-console')).toHaveTextContent('invalid');
    expect(screen.getByTestId('domain-selector-example-console')).toHaveClass(
      'domain-selector__example-domain-invalid',
    );

    expect(container).toMatchSnapshot();
  });

  it('can can handle valid domain', () => {
    const { container } = render(<Component ctxData={{ domain: 'valid.com' }} />);

    expect(screen.queryAllByTestId('domain-validation-failed')).toHaveLength(0);
    expect(screen.getByTestId('domain-selector-example-setup')).toHaveTextContent('valid.com');
    expect(screen.getByTestId('domain-selector-example-setup')).toHaveClass(
      'domain-selector__example-domain',
    );
    expect(screen.getByTestId('domain-selector-example-console')).toHaveTextContent('valid.com');
    expect(screen.getByTestId('domain-selector-example-console')).toHaveClass(
      'domain-selector__example-domain',
    );

    expect(container).toMatchSnapshot();
  });
});
