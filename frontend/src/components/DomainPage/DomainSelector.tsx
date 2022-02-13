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
        <Title headingLevel="h1">Domain</Title>
      </StackItem>
      <StackItem>
        Would you like to set up local domain? <OptionalBadge />
      </StackItem>
      <StackItem isFilled className="domain-item">
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
    </Stack>
  );
};
