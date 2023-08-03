import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Stack,
  StackItem,
  Title,
} from '@patternfly/react-core';
import { useNavigate } from 'react-router-dom';

import './WelcomeBottom.css';

export const WelcomeBottom: React.FC<{ error?: string; nextPage?: string }> = ({
  error,
  nextPage,
}) => {
  const navigate = useNavigate();

  return (
    <Stack className="welcome-bottom" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Edge cluster</Title>
      </StackItem>
      <StackItem isFilled>
        To set up the configuration of your edge cluster, click Continue.
      </StackItem>
      {error && (
        <StackItem>
          <Alert
            title="Connection failed"
            variant={AlertVariant.danger}
            isInline
            className="welcome-bottom__error"
          >
            {error}
          </Alert>
        </StackItem>
      )}
      <StackItem>
        <Button
          component="a"
          data-testid="welcome-button-continue"
          onClick={() => navigate(nextPage || '/welcome')}
          variant={ButtonVariant.primary}
          isDisabled={!nextPage}
        >
          Continue
        </Button>
      </StackItem>
    </Stack>
  );
};
