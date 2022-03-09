import React from 'react';
import { FormGroup, Stack, StackItem, TextInput, Title } from '@patternfly/react-core';

import { OptionalBadge } from '../Badge';
import { useK8SStateContext } from '../K8SStateContext';

import './DomainSelector.css';

const fieldId = 'input-domain';

export const DomainSelector: React.FC = () => {
  const { domain, handleSetDomain, domainValidation: validation } = useK8SStateContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Do you want to use a custom domain?</Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Create unique URLs for your KubeFrame, such as device setup and console. <OptionalBadge />
      </StackItem>
      <StackItem className="domain-item">
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && (
              <div data-testid="domain-validation-failed" className="validation-failed-text">
                {validation}
              </div>
            )
          }
          validated={validation ? 'error' : 'default'}
        >
          <TextInput
            id={fieldId}
            value={domain}
            validated={validation ? 'error' : 'default'}
            isRequired={false}
            onChange={handleSetDomain}
          />
        </FormGroup>
      </StackItem>
      <StackItem isFilled>
        <div className="domain-selector__example">
          Setup URL: https://setup.
          <span
            data-testid="domain-selector-example-setup"
            className={
              validation
                ? 'domain-selector__example-domain-invalid'
                : 'domain-selector__example-domain'
            }
          >
            {domain}
          </span>
        </div>
        <div className="domain-selector__example">
          Console URL: https://console.
          <span
            data-testid="domain-selector-example-console"
            className={
              validation
                ? 'domain-selector__example-domain-invalid'
                : 'domain-selector__example-domain'
            }
          >
            {domain}
          </span>
        </div>
      </StackItem>
    </Stack>
  );
};
