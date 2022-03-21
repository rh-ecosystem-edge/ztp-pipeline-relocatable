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

import { RequiredBadge } from '../Badge';
import { HelperTextInvalid } from '../HelperTextInvalid';
import { useK8SStateContext } from '../K8SStateContext';
import { PasswordRequirements } from './PasswordRequirements';

import './PasswordSelector.css';

const fieldId = 'input-password';
const fieldId2 = 'input-password-check';

export const PasswordSelector: React.FC<{
  equalityValidationCheck?: string;
  setEqualityValidationCheck: (result: string) => void;
}> = ({ equalityValidationCheck, setEqualityValidationCheck }) => {
  const { password, handleSetPassword, passwordValidation: validation } = useK8SStateContext();
  const [passwordCheck, setPasswordCheck] = React.useState(''); // content of the input-box
  const [isVisible, setVisible] = React.useState(false);

  const validateEquality = React.useCallback(() => {
    if (password !== passwordCheck) {
      setEqualityValidationCheck('Passwords does not match.');
    } else {
      setEqualityValidationCheck('');
    }
  }, [setEqualityValidationCheck, passwordCheck, password]);

  React.useEffect(() => validateEquality(), [validateEquality, passwordCheck, password]);

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">
          Choose a password <RequiredBadge />
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Keep your edge cluster account safe and secure.
      </StackItem>
      <StackItem>
        <FormGroup
          fieldId={fieldId}
          // helperTextInvalid={
          //   validation && <div className="validation-failed-text">{validation}</div>
          // }
          validated={validation ? 'default' : 'error'}
        >
          <TextInput
            id={fieldId}
            data-testid={fieldId}
            value={password}
            validated={validation ? 'default' : 'error'}
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
          <PasswordRequirements />
        </FormGroup>
      </StackItem>
      <StackItem className="pasword-sublabel-item">
        <Title headingLevel="h4">Confirm password</Title>
      </StackItem>
      <StackItem isFilled>
        <FormGroup
          fieldId={fieldId2}
          helperTextInvalid={
            <HelperTextInvalid
              id="password__equality-validation"
              validation={equalityValidationCheck}
            />
          }
          validated={equalityValidationCheck ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId2}
            data-testid={fieldId2}
            value={passwordCheck}
            validated={equalityValidationCheck ? 'error' : 'default'}
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
