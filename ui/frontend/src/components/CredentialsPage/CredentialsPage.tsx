import React from 'react';
import {
  TextContent,
  TextVariants,
  Text,
  FormGroup,
  Spinner,
  FormGroupProps,
  TextInput,
  Button,
  ButtonVariant,
} from '@patternfly/react-core';
import { EyeIcon, EyeSlashIcon } from '@patternfly/react-icons';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { UIError } from '../types';
import { isKubeAdmin } from '../../resources/oauth';
import { reloadPage } from '../utils';

import { loadCredentials } from './dataLoad';
import { passwordValidator, usernameValidator } from './utils';
import { PasswordRequirements } from './PasswordRequirements';
import { HelperTextInvalid } from './HelperTextInvalid';
import { persistIdentityProvider, PersistIdentityProviderResult } from './persist';
import { DeleteKubeadminButton } from './DeleteKubeadminButton';

import './CredentialsPage.css';
import { getSecret } from '../../resources/secret';
import { KubeadminSecret } from '../constants';

export const CredentialsPage = () => {
  const [error, setError] = React.useState<UIError>();
  const [username, setUsername] = React.useState<string>('');
  const [password, setPassword] = React.useState<string>('');
  const [passwordCheck, setPasswordCheck] = React.useState<string>('');
  const [isVisible, setVisible] = React.useState(false);
  const [isAdminCreated, setIsAdminCreated] = React.useState(false);
  const [isKubeadminDeleted, setIsKubeadminDeleted] = React.useState(false);
  const [isKubeAdminLoggedIn, setIsKubeAdminLoggedIn] = React.useState(true);
  const [isSaving, setIsSaving] = React.useState(false);
  const [usernameValidation, setUsernameValidation] = React.useState<string>();
  const [passwordValidation, setPasswordValidation] = React.useState<boolean>();
  const [equalityValidationCheck, setEqualityValidationCheck] = React.useState<string>();

  const validateEquality = React.useCallback(() => {
    if (password !== passwordCheck) {
      setEqualityValidationCheck('Passwords does not match.');
    } else {
      setEqualityValidationCheck('');
    }
  }, [setEqualityValidationCheck, passwordCheck, password]);

  React.useEffect(() => validateEquality(), [validateEquality, passwordCheck, password]);

  const onSetUser = (newUser: string) => {
    setUsername(newUser);
    setUsernameValidation(usernameValidator(newUser));
  };
  const onSetPassword = (newPassword: string) => {
    setPassword(newPassword);
    setPasswordValidation(passwordValidator(newPassword));
  };

  const onSave = async () => {
    if (!username || !password) {
      // Should not happen
      return;
    }

    setIsSaving(true);

    const result = await persistIdentityProvider(setError, username, password);

    setIsSaving(false);

    if (result !== PersistIdentityProviderResult.error) {
      reloadPage();
    }
  };

  React.useEffect(
    () => {
      const doItAsync = async () => {
        const { isAdminCreated } = await loadCredentials({ setError });
        setIsAdminCreated(isAdminCreated);

        const ika = await isKubeAdmin();
        setIsKubeAdminLoggedIn(ika === undefined || ika);

        try {
          await getSecret(KubeadminSecret).promise;
        } catch (e) {
          setIsKubeadminDeleted(true);
        }
      };

      doItAsync();
    },
    [
      /* Just once */
    ],
  );

  const isValid: boolean =
    !!username &&
    !usernameValidation &&
    !!password &&
    !!passwordValidation &&
    !equalityValidationCheck;

  let usernameValidated: FormGroupProps['validated'] = 'default';
  if (!username || usernameValidation) {
    usernameValidated = 'error';
  } else if (usernameValidation !== undefined) {
    usernameValidated = 'success';
  }

  const actions = [
    <DeleteKubeadminButton key="delete-kubeadmin" className="basic-layout__extra-action" />,
  ];

  return (
    <Page>
      <BasicLayout
        error={error}
        isValueChanged={isValid}
        isSaving={isSaving}
        onSave={isAdminCreated ? undefined : onSave}
        actions={actions}
      >
        {isAdminCreated && (
          <ContentSection>
            <TextContent>
              <Text component={TextVariants.h1}>Personalized administrator account is created</Text>
              {isKubeAdminLoggedIn && (
                <Text className="text-sublabel">
                  For security reasons, it is advised to use the new administrator account instead
                  of the factory-provided kubeadmin. To delete the kubeadmin account, log out curent
                  session and log in using the new account.
                </Text>
              )}
              {isKubeadminDeleted && (
                <Text className="text-sublabel">
                  The factory-provided kubeadmin account has been deleted and you are logged in
                  using a personalized account. Your are all set here.
                </Text>
              )}
              {!isKubeAdminLoggedIn && !isKubeadminDeleted && (
                <Text className="text-sublabel">
                  For security reasons, it is advised to use the new administrator account instead
                  of the factory-provided kubeadmin. To delete the factory-provided kubeadmin
                  account, use the button bellow.
                </Text>
              )}
            </TextContent>
          </ContentSection>
        )}

        {!isAdminCreated && (
          <>
            <ContentSection>
              <TextContent>
                <Text component={TextVariants.h1}>Username</Text>
                <Text className="text-sublabel">
                  Create a new administrator account for future access.
                </Text>
              </TextContent>
              <br />
              {username === undefined && <Spinner size="sm" />}
              {username !== undefined && (
                <FormGroup
                  fieldId="username"
                  label="Username"
                  isRequired={true}
                  helperTextInvalid={usernameValidation}
                  validated={usernameValidated}
                >
                  <TextInput
                    id="username"
                    data-testid="username"
                    value={username}
                    validated={usernameValidated}
                    onChange={onSetUser}
                    className="credentials-input"
                  />
                </FormGroup>
              )}
            </ContentSection>

            <ContentSection>
              <TextContent>
                <Text component={TextVariants.h1}>Password</Text>
                <Text className="text-sublabel">Keep your OpenShift account safe and secure.</Text>
              </TextContent>
              <br />
              <FormGroup
                fieldId="password"
                label="New password"
                isRequired={true}
                helperTextInvalid={passwordValidation}
                validated={passwordValidation ? 'error' : 'success'}
              >
                <TextInput
                  id="password"
                  data-testid="password"
                  value={password}
                  validated={passwordValidation ? 'default' : 'error'}
                  onChange={onSetPassword}
                  type={isVisible ? 'text' : 'password'}
                  className="credentials-input"
                />
                <Button
                  variant={ButtonVariant.control}
                  aria-label="Show password"
                  onClick={() => setVisible(!isVisible)}
                >
                  {isVisible ? <EyeIcon /> : <EyeSlashIcon />}
                </Button>
                <PasswordRequirements password={password} />
              </FormGroup>
              <br />
              <FormGroup
                fieldId="password-confirm"
                label="Confirm password"
                isRequired={true}
                helperTextInvalid={
                  <HelperTextInvalid
                    id="password__equality-validation"
                    validation={equalityValidationCheck}
                  />
                }
                validated={equalityValidationCheck ? 'error' : 'default'}
              >
                <TextInput
                  id="password-confirm"
                  data-testid="password-confirm"
                  value={passwordCheck}
                  validated={equalityValidationCheck ? 'error' : 'default'}
                  isRequired={false}
                  onChange={setPasswordCheck}
                  type={isVisible ? 'text' : 'password'}
                  className="credentials-input"
                />
                <Button
                  variant={ButtonVariant.control}
                  aria-label="Show password"
                  onClick={() => setVisible(!isVisible)}
                >
                  {isVisible ? <EyeIcon /> : <EyeSlashIcon />}
                </Button>
              </FormGroup>
            </ContentSection>
          </>
        )}
      </BasicLayout>
    </Page>
  );
};
