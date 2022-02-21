import React from 'react';
import { FormGroup, Stack, StackItem, TextInput, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';

import './PasswordSelector.css';

const fieldId = 'input-domain';

export const PasswordSelector: React.FC = () => {
  const {
    state: { password, handleSetPassword, passwordValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          Choose a password <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem>
        Keep your KubeFrame account safe and secure.
        <RequiredBadge />
      </StackItem>
      <StackItem className="password-item" isFilled>
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && <div className="validation-failed-text">{validation}</div>
          }
          validated={validation ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId}
            value={password}
            validated={validation ? 'error' : 'default'}
            isRequired={false}
            onChange={handleSetPassword}
          />
        </FormGroup>
      </StackItem>
    </Stack>
  );
};
