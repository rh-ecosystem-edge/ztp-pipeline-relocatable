import React from 'react';
import { FormGroup, Stack, StackItem, TextInput, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { OptionalBadge } from '../Badge';

import './DomainSelector.css';

const fieldId = 'input-domain';

export const DomainSelector: React.FC = () => {
  const {
    state: { domain, handleSetDomain, domainValidation: validation },
  } = useWizardProgressContext();

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">Do you want to use a custom domain?</Title>
      </StackItem>
      <StackItem>
        Create unique URLs for your KubeFrame, such as device setup and console. <OptionalBadge />
      </StackItem>
      <StackItem className="domain-item">
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && <div className="validation-failed-text">{validation}</div>
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
          Setup URL: https://setup.<span className="domain-selector__example-domain">{domain}</span>
        </div>
        <div className="domain-selector__example">
          Console URL: https://console.
          <span className="domain-selector__example-domain">{domain}</span>
        </div>
      </StackItem>
    </Stack>
  );
};
