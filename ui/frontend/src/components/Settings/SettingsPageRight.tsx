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

import { navigateToNewDomain, persist, PersistErrorType } from '../PersistPage';
import { IpTripletsSelector } from '../IpTripletsSelector';
import { useK8SStateContext } from '../K8SStateContext';
import { DeleteKubeadminButton } from './DeleteKubeadminButton';
import { PersistProgress, usePersistProgress } from '../PersistProgress';

import './SettingsPageRight.css';

export const SettingsPageRight: React.FC<{
  isInitialEdit?: boolean;
  initialError?: string;
  forceReload: () => void;
}> = ({ isInitialEdit, initialError, forceReload }) => {
  const [isEdit, setEdit] = React.useState(isInitialEdit);
  const [isSaving, setIsSaving] = React.useState(false);
  const [_error, setError] = React.useState<PersistErrorType>();
  const state = useK8SStateContext();
  const progress = usePersistProgress();

  const error: PersistErrorType | undefined = initialError
    ? {
        title: 'Connection failed',
        message: initialError,
      }
    : _error;

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

  const onSave = async () => {
    setIsSaving(true);
    setError(undefined);
    await persist(state, setError, progress.setProgress, onSuccess);
    setIsSaving(false);
  };

  const onSuccess = () => {
    setError(null);
    setEdit(false);

    navigateToNewDomain(domain, '/settings');
  };

  const onCancelEdit = () => {
    setEdit(false);
    forceReload();
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
            helperTextInvalid={apiaddrValidation.message}
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
            helperTextInvalid={ingressIpValidation.message}
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
            helperTextInvalid={domainValidation}
            validated={!domainValidation ? 'default' : 'error'}
          >
            <TextInput
              id="domain"
              data-testid="settings-page-input-domain"
              value={domain}
              validated={!domainValidation ? 'default' : 'error'}
              onChange={handleSetDomain}
              isDisabled={!isEdit}
            />
          </FormGroup>
        </StackItem>
        {error && (
          <StackItem isFilled className="summary-page-sumamary__item">
            <Alert
              data-testid="settings-page-alert-error"
              title={error.title}
              variant={AlertVariant.danger}
              isInline
            >
              {error.message}
            </Alert>
          </StackItem>
        )}
        {error === null && (
          <StackItem isFilled className="summary-page-sumamary__item">
            <Alert
              data-testid="settings-page-alert-all-saved"
              title="Changes saved"
              variant={AlertVariant.success}
              isInline
            >
              All changes have been saved, it might take several minutes for cluster to reconcile.
              <PersistProgress progress={progress.progress} progressError={!!error} />
            </Alert>
          </StackItem>
        )}
        {/* TODO: Fix logic around isSaving and error here!!!! */}
        {error === undefined && (
          <StackItem isFilled>
            {isSaving && <PersistProgress progress={progress.progress} progressError={!!error} />}
          </StackItem>
        )}
        <StackItem className="settings-page-sumamary__item__footer">
          {!isEdit && (
            <>
              <DeleteKubeadminButton />{' '}
              <Button
                data-testid="settings-page-button-edit"
                variant={ButtonVariant.primary}
                onClick={() => setEdit(true)}
                disabled={
                  /* wait for changes to take effect, do another change on the new page after redirection */
                  error === null
                }
              >
                Edit
              </Button>
            </>
          )}
          {isEdit && (
            <>
              <Button
                data-testid="settings-page-button-save"
                variant={ButtonVariant.primary}
                onClick={onSave}
                isDisabled={isSaving}
              >
                Save
              </Button>
              <Button
                data-testid="settings-page-button-cancel"
                variant={ButtonVariant.link}
                onClick={onCancelEdit}
              >
                Cancel
              </Button>
            </>
          )}
        </StackItem>
      </Stack>
    </Form>
  );
};
