import { Button, ButtonVariant } from '@patternfly/react-core';
import React from 'react';

export const ActionCountDown: React.FC<{ action: () => void; initial?: number }> = ({
  action,
  initial = 120,
}) => {
  const [counter, setCounter] = React.useState(initial);

  React.useEffect(() => {
    if (counter > 0) {
      const timer = setInterval(() => setCounter(counter - 1), 1000);
      return () => clearInterval(timer);
    } else {
      action();
    }
  }, [counter, action]);

  return (
    <>
      ({counter}s
      <Button variant={ButtonVariant.link} onClick={action}>
        Try now
      </Button>
      )
    </>
  );
};
