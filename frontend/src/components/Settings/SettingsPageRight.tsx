import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Form,
  FormGroup,
  Stack,
  StackItem,
  TextInput,
  Title,
} from '@patternfly/react-core';
import { useWizardState } from '../Wizard/wizardState';
import { persist, PersistErrorType } from '../PersistPage';

import './SettingsPageRight.css';
import { ipWithDots } from '../utils';
import { IpTripletsSelector } from '../IpTripletsSelector';

export const SettingsPageRight: React.FC<{ isInitialEdit?: boolean }> = ({ isInitialEdit }) => {
  const [isEdit, setEdit] = React.useState(isInitialEdit);
  const [error, setError] = React.useState<PersistErrorType>();
  const state = useWizardState();
  const {
    apiaddr,
    apiaddrValidation,
    handleSetApiaddr,

    ingressIp,
    ingressIpValidation,
    handleSetIngressIp,

    domain,
    domainValidation,
    handleSetDomain,
  } = state;

  const onSave = () => {
    setError(undefined);
    persist(state, setError, onSuccess);
  };

  const onSuccess = () => {
    setError(null);
    setEdit(false);
  };

  const onCancelEdit = () => {
    setEdit(false);
    console.error('TODO: reload initial data');
  };

  return (
    <Form className="settings-page-sumamary__form">
      <Stack hasGutter className="settings-page-sumamary">
        <StackItem className="final-page-sumamary__item">
          <Title headingLevel="h1">Settings</Title>
        </StackItem>
        <StackItem className="summary-page-sumamary__item">
          <FormGroup
            fieldId="apiaddr"
            label="API address"
            isRequired={true}
            helperTextInvalid={apiaddrValidation.message || 'TODO: foooo'}
            validated={apiaddrValidation.valid ? 'default' : 'error'}
          >
            <IpTripletsSelector
              id="apiaddr"
              address={apiaddr}
              setAddress={handleSetApiaddr}
              validation={apiaddrValidation}
              isDisabled={!isEdit}
              isNarrow
            />
          </FormGroup>
        </StackItem>
        <StackItem className="summary-page-sumamary__item">
          <FormGroup
            fieldId="ingressip"
            label="Ingress address"
            isRequired={true}
            helperTextInvalid={ingressIpValidation.message || 'TODO: baaaaar'}
            validated={ingressIpValidation.valid ? 'default' : 'error'}
          >
            <IpTripletsSelector
              id="ingress-ip"
              address={ingressIp}
              setAddress={handleSetIngressIp}
              validation={ingressIpValidation}
              isDisabled={!isEdit}
              isNarrow
            />
          </FormGroup>
        </StackItem>
        <StackItem className="summary-page-sumamary__item">
          <FormGroup
            fieldId="domain"
            label="Domain"
            isRequired={false}
            helperTextInvalid={domainValidation || 'baaaaar'}
            validated={!domainValidation ? 'default' : 'error'}
          >
            <TextInput
              id="domain"
              value={domain}
              validated={!domainValidation ? 'default' : 'error'}
              onChange={handleSetDomain}
              isDisabled={!isEdit}
            />
          </FormGroup>
        </StackItem>
        {error && (
          <StackItem isFilled className="summary-page-sumamary__item">
            <Alert title={error.title} variant={AlertVariant.danger} isInline>
              {error.message}
            </Alert>
          </StackItem>
        )}
        {error === null && (
          <StackItem isFilled className="summary-page-sumamary__item">
            <Alert title="Changes saved" variant={AlertVariant.success} isInline>
              All changes have been saved.
            </Alert>
          </StackItem>
        )}
        {error === undefined && <StackItem isFilled></StackItem>}
        <StackItem className="settings-page-sumamary__item__footer">
          {!isEdit && (
            <Button variant={ButtonVariant.primary} onClick={() => setEdit(true)}>
              Edit
            </Button>
          )}
          {isEdit && (
            <>
              <Button variant={ButtonVariant.primary} onClick={onSave}>
                Save
              </Button>
              <Button variant={ButtonVariant.link} onClick={onCancelEdit}>
                Cancel
              </Button>
            </>
          )}
        </StackItem>
      </Stack>
    </Form>
  );
};
