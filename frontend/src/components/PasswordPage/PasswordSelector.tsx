import React from 'react';
import {
  Button,
  ButtonVariant,
  FormGroup,
  Stack,
  StackItem,
  TextInput,
  Title,
} from '@patternfly/react-core';
import { EyeIcon, EyeSlashIcon } from '@patternfly/react-icons';

import { useWizardProgressContext } from '../WizardProgress';
import { RequiredBadge } from '../Badge';

import './PasswordSelector.css';

const fieldId = 'input-password';
const fieldId2 = 'input-password-check';

export const PasswordSelector: React.FC = () => {
  const {
    state: { password, handleSetPassword, passwordValidation: validation },
  } = useWizardProgressContext();
  const [isVisible, setVisible] = React.useState(false);

  const [passwordCheck, setPasswordCheck] = React.useState('');
  const [validationCheck, setValidationCheck] = React.useState('');

  const validateEquality = React.useCallback(() => {
    if (password !== passwordCheck) {
      setValidationCheck('Passwords does not match.');
    } else {
      setValidationCheck('');
    }
  }, [setValidationCheck, passwordCheck, password]);

  React.useEffect(() => validateEquality(), [validateEquality, passwordCheck, password]);

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          Choose a password <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem>Keep your KubeFrame account safe and secure.</StackItem>
      <StackItem>
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
            type={isVisible ? 'text' : 'password'}
            className="password-item"
          />
          <Button
            variant={ButtonVariant.control}
            aria-label="Show password"
            onClick={() => setVisible(!isVisible)}
          >
            {isVisible ? <EyeIcon /> : <EyeSlashIcon />}
          </Button>
        </FormGroup>
      </StackItem>
      <StackItem isFilled>
        <span>Retype password</span>
        <FormGroup
          fieldId={fieldId2}
          helperTextInvalid={
            validationCheck && <div className="validation-failed-text">{validationCheck}</div>
          }
          validated={validationCheck ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId}
            value={passwordCheck}
            validated={validationCheck ? 'error' : 'default'}
            isRequired={false}
            onChange={setPasswordCheck}
            type={isVisible ? 'text' : 'password'}
            className="password-item"
          />
          <Button
            variant={ButtonVariant.control}
            aria-label="Show password"
            onClick={() => setVisible(!isVisible)}
          >
            {isVisible ? <EyeIcon /> : <EyeSlashIcon />}
          </Button>
        </FormGroup>
      </StackItem>
    </Stack>
  );
};
