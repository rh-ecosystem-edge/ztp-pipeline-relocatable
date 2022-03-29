import React from 'react';
import { FormGroup, Stack, StackItem, TextInput, Title } from '@patternfly/react-core';

import { RequiredBadge } from '../Badge';
import { useK8SStateContext } from '../K8SStateContext';

import './UsernameSelector.css';

const fieldId = 'input-username';

export const UsernameSelector: React.FC = () => {
  const { username, handleSetUsername, usernameValidation: validation } = useK8SStateContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          Choose a username <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Create a new personalized, account for future access replacing recent kbeadmin user.
      </StackItem>
      <StackItem className="username-item" isFilled>
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && (
              <div data-testid="validation-failed-text" className="validation-failed-text">
                {validation}
              </div>
            )
          }
          validated={validation ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId}
            data-testid={fieldId}
            value={username}
            validated={validation ? 'error' : 'default'}
            isRequired={false}
            onChange={handleSetUsername}
          />
        </FormGroup>
      </StackItem>
    </Stack>
  );
};
