import React from 'react';
import { FormGroup, Stack, StackItem, TextInput, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';

import './UsernameSelector.css';

const fieldId = 'input-username';

export const UsernameSelector: React.FC = () => {
  const {
    state: { username, handleSetUsername, usernameValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          Choose a username <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Create a new personalized, account for future access.
      </StackItem>
      <StackItem className="username-item" isFilled>
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && <div className="validation-failed-text">{validation}</div>
          }
          validated={validation ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId}
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
