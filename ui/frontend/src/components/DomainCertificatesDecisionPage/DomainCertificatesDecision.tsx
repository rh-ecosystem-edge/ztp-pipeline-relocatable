import React from 'react';
import { Radio, Split, SplitItem, Stack, StackItem, Title } from '@patternfly/react-core';

// import './DomainCertificatesDecision.css';

export const DomainCertificatesDecision: React.FC<{
  isAutomatic: boolean;
  setAutomatic: (isAutomatic: boolean) => void;
}> = ({ isAutomatic, setAutomatic }) => {
  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">How do you want to assign certificates to your domain?</Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Choose whether or not you want to automatically assign self-signed certificates for your
        custom domain.
      </StackItem>
      <StackItem>
        <Split hasGutter>
          {/* TODO: Improve positioning on the page */}
          <SplitItem>
            <Radio
              data-testid="domain-cert-decision__automatic"
              id="domain-cert-decision__automatic"
              label="Automatic"
              name="automatic"
              isChecked={isAutomatic}
              onChange={() => setAutomatic(true)}
            />
          </SplitItem>
          <SplitItem>
            <Radio
              data-testid="domain-cert-decision__manual"
              id="domain-cert-decision__manual"
              label="Manual"
              name="manual"
              isChecked={!isAutomatic}
              onChange={() => setAutomatic(false)}
            />
          </SplitItem>
        </Split>
      </StackItem>
    </Stack>
  );
};
