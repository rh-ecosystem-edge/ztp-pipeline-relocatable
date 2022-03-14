import React from 'react';
import { render, screen } from '@testing-library/react';

import { UsernameSelector } from './UsernameSelector';
import { K8SStateContextProvider, useK8SStateContext } from '../K8SStateContext';

const TestedComponent: React.FC<{
  ctxData?: { username: string };
}> = ({ ctxData }) => {
  const { handleSetUsername } = useK8SStateContext();
  React.useEffect(() => {
    if (ctxData) {
      handleSetUsername(ctxData.username);
    }
  }, [ctxData, handleSetUsername]);

  return <UsernameSelector />;
};

const Component: React.FC<{
  ctxData?: { username: string };
}> = ({ ctxData }) => (
  <K8SStateContextProvider>
    <TestedComponent ctxData={ctxData} />
  </K8SStateContextProvider>
);

describe('UsernameSelector', () => {
  it('can render', () => {
    const { container } = render(<Component />);
    expect(screen.queryAllByTestId('username-validation-failed')).toHaveLength(0);
    expect(container).toMatchSnapshot();
  });

  it('can can handle invalid domain', () => {
    const { container } = render(<Component ctxData={{ username: 'invalid-' }} />);
    expect(container).toMatchSnapshot();

    expect(screen.getByTestId('validation-failed-text')).toHaveTextContent(
      "Valid username wasn't provided",
    );

    expect(container).toMatchSnapshot();
  });
});
