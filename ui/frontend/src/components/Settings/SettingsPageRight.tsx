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
  Tabs,
  Tab,
  TabTitleText,
} from '@patternfly/react-core';

import { navigateToNewDomain, persist, PersistErrorType } from '../PersistPage';
import { IpTripletsSelector } from '../IpTripletsSelector';
import { useK8SStateContext } from '../K8SStateContext';
import { DeleteKubeadminButton } from './DeleteKubeadminButton';
import { PersistProgress, usePersistProgress } from '../PersistProgress';
import { SettingsPageDomainCertificates } from './SettingsPageDomainCertificates';
import { useSettingsPageContext } from './SettingsPageContext';

import './SettingsPageRight.css';

export const SettingsPageRight: React.FC<{
  initialError?: string;
  forceReload: () => void;
}> = ({ initialError, forceReload }) => {
  const [isSaving, setIsSaving] = React.useState(false);
  const [_error, setError] = React.useState<PersistErrorType>();
  const { activeTabKey, setActiveTabKey, isEdit, setEdit } = useSettingsPageContext();
  const state = useK8SStateContext();
  const progress = usePersistProgress();

  const error: PersistErrorType | undefined = initialError
    ? {
        title: 'Connection failed',
        message: initialError,
      }
    : _error;

  const {
    isDirty,
    setClean,

    apiaddr,
    apiaddrValidation,
    handleSetApiaddr,

    ingressIp,
    ingressIpValidation,
    handleSetIngressIp,

    domain,
    originalDomain,
    domainValidation,
    handleSetDomain,
  } = state;

  const onSuccess = () => {
    setError(null);
    setEdit(false);
    setClean();

    navigateToNewDomain(domain, '/settings#redirected');
  };

  const onSave = async () => {
    setIsSaving(true);
    setError(undefined);
    await persist(state, setError, progress.setProgress, onSuccess);
    setIsSaving(false);
  };

  const isAfterRedirection = window.location.hash === '#redirected';
  const isDomainChange = originalDomain && originalDomain !== domain;

  const onCancelEdit = () => {
    setEdit(false);
    forceReload();
  };

  const isSaveDisabled = isSaving || !isDirty();

  return (
    <Stack className="settings-page-sumamary">
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h1">Settings</Title>
      </StackItem>

      <StackItem>
        <Tabs
          activeKey={activeTabKey}
          onSelect={(_, tabIndex) => setActiveTabKey(tabIndex as number)}
          isBox={false}
          aria-label="Choose tab to configure"
        >
          <Tab id="settings-tab-0" eventKey={0} title={<TabTitleText>TCP/IP</TabTitleText>}>
            <Stack>
              <StackItem className="summary-page-sumamary__item">
                <Form className="settings-page-sumamary__form">
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
                </Form>
              </StackItem>
              <StackItem className="summary-page-sumamary__item">
                <Form>
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
                </Form>
              </StackItem>
            </Stack>
          </Tab>

          <Tab id="settings-tab-1" eventKey={1} title={<TabTitleText>Domain</TabTitleText>}>
            <Form>
              <Stack className="settings-page-sumamary__tab">
                <StackItem>
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
                {isEdit && isDomainChange && <SettingsPageDomainCertificates />}
              </Stack>
            </Form>
          </Tab>
        </Tabs>
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
      {isSaving && (
        <StackItem isFilled className="summary-page-sumamary__item">
          <PersistProgress
            className="settings-page-sumamary__persist-progress"
            {...progress}
            progressError={!!error}
          />
          {error === null && (
            <>
              All changes have been saved, it might take several minutes for cluster to reconcile.
            </>
          )}
        </StackItem>
      )}
      {!isSaving && !error && (
        <StackItem isFilled className="summary-page-sumamary__item">
          {/* Just a placeholder */}
        </StackItem>
      )}
      {isAfterRedirection && !isSaving && !isEdit && (
        <StackItem className="summary-page-sumamary__item">
          {/* TODO: Do we want to show 100% progressbar here? After redirection, it can be a fake one... */}
          All changes have been saved.
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
              isDisabled={isSaveDisabled}
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
  );
};
