import React from 'react';
import {
  TextContent,
  TextVariants,
  Text,
  FormGroup,
  Spinner,
  TextInput,
  Radio,
} from '@patternfly/react-core';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { CertificateProps, CustomCertsValidationType, UIError } from '../types';
import { customCertsValidator, domainValidator } from '../utils';
import { CustomCertsType } from '../../copy-backend-common';

import { loadDomainData } from './dataLoad';
import { persistDomain, validateDomainBackend } from './persist';
import { DomainCertificatesPanel } from './DomainCertificates';

import './DomainPage.css';

export const DomainPage = () => {
  const [error, setError] = React.useState<UIError>();
  const [domain, setDomain] = React.useState<string>();
  const [loadedValue, setLoadedValue] = React.useState<string>();
  const [isSaving, setIsSaving] = React.useState(false);
  const [isValidating, setIsValidating] = React.useState(false);
  const [validation, setValidation] = React.useState<string>();
  const [isAutomatic, setAutomatic] = React.useState(true);
  const [customCerts, setCustomCerts] = React.useState<CustomCertsType>({});
  const [customCertsValidation, setCustomCertsValidation] =
    React.useState<CustomCertsValidationType>({});

  React.useEffect(
    () => {
      const doItAsync = async () => {
        const d = (await loadDomainData({ setError })) || '';
        handleSetDomain(d);
        setLoadedValue(d);
      };

      doItAsync();
    },
    [
      /* Just once */
    ],
  );

  const handleSetDomain = (newDomain: string) => {
    setDomain(newDomain);
    setValidation(domainValidator(newDomain));
  };

  const onSave = async () => {
    if (!domain) {
      return;
    }

    setIsValidating(true);
    const isResolvable = await validateDomainBackend((message) => {
      // Backend failed to pre-validate the domain (most probably the domain can not be resolved, the "dig" command failed)
      setValidation(message);
    }, domain);
    setIsValidating(false);

    if (isResolvable) {
      setIsSaving(true);
      await persistDomain(setError, domain, customCerts);
      setIsSaving(false);
    }
  };

  const clearCustomCertificates = () => {
    setCustomCerts({});
    setCustomCertsValidation({});
  };

  const setCustomCertificate: CertificateProps['setCustomCertificate'] = (domain, certificate) => {
    const newCustomCerts = { ...customCerts };
    newCustomCerts[domain] = certificate;
    setCustomCerts(newCustomCerts);
    setCustomCertsValidation(customCertsValidator(customCertsValidation, domain, certificate));
  };

  const successfulDomains = Object.keys(customCertsValidation).filter(
    (domain) =>
      customCertsValidation[domain].certValidated === 'success' &&
      customCertsValidation[domain].keyValidated === 'success',
  );

  const isValueChanged = !isValidating && (loadedValue !== domain || successfulDomains.length > 0);

  return (
    <Page>
      <BasicLayout
        error={error}
        isValueChanged={isValueChanged}
        isSaving={isSaving}
        onSave={onSave}
      >
        <ContentSection>
          <TextContent>
            <Text component={TextVariants.h1}>Domain</Text>
            <Text className="text-sublabel">
              Create unique URLs for your edge cluster, such as device setup and the console.
            </Text>
          </TextContent>
          <br />
          {domain === undefined && <Spinner size="sm" />}
          {domain !== undefined && (
            <FormGroup
              fieldId="domain"
              label="Domain"
              isRequired={true}
              helperTextInvalid={validation}
              validated={validation ? 'error' : 'default'}
            >
              <TextInput
                id="domain"
                data-testid="domain"
                value={domain}
                validated={validation ? 'error' : 'default'}
                onChange={handleSetDomain}
              />
            </FormGroup>
          )}
        </ContentSection>

        {domain && (
          <ContentSection>
            <TextContent>
              <Text component={TextVariants.h1}>Domain certificates</Text>
              <Text className="text-sublabel">
                Choose whether or not you want to automatically assign certificates for your custom
                domain.
              </Text>
            </TextContent>
            <br />

            <FormGroup
              fieldId="domaincertsswitch__auto"
              label="Domain certificate configuration"
              isRequired={true}
              className="domain-page__domain-certs-switch"
            >
              <Radio
                data-testid="domaincertsswitch__auto"
                id="domaincertsswitch__auto"
                label="Automatic"
                name="automatic"
                isChecked={isAutomatic}
                onChange={() => {
                  setAutomatic(true);
                  clearCustomCertificates();
                }}
              />
              <Radio
                data-testid="domaincertsswitch__manual"
                id="domaincertsswitch__manual"
                label="Manual"
                name="manual"
                isChecked={!isAutomatic}
                onChange={() => setAutomatic(false)}
              />
            </FormGroup>
          </ContentSection>
        )}

        {!isAutomatic && domain && (
          <ContentSection>
            <TextContent>
              <Text component={TextVariants.h1}>Upload custom certificates</Text>
              <Text className="text-sublabel">
                Secure your SSL/TLS routes with certificates in the PEM format.
              </Text>
              <Text className="text-sublabel">
                If a certificate is not provided, a self-signed one will be automatically
                generated..
              </Text>
            </TextContent>
            <br />
            <DomainCertificatesPanel
              domain={domain}
              isScrollable={false}
              customCerts={customCerts}
              setCustomCertificate={setCustomCertificate}
              customCertsValidation={customCertsValidation}
            />
          </ContentSection>
        )}
      </BasicLayout>
    </Page>
  );
};
