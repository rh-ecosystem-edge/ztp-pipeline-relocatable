import React from 'react';
import { Radio, Split, SplitItem, Stack, StackItem, Title } from '@patternfly/react-core';

type AutomaticManualDecisionProps = {
  id?: string;
  isAutomatic: boolean;
  setAutomatic: (isAutomatic: boolean) => void;
};

export const AutomaticManualDecision: React.FC<AutomaticManualDecisionProps> = ({
  id,
  isAutomatic,
  setAutomatic,
}) => (
  <Split hasGutter id={id}>
    {/* TODO: Improve positioning on the Wizard's page */}
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
);

export const DomainCertificatesDecision: React.FC<AutomaticManualDecisionProps> = (props) => {
  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">How do you want to assign certificates to your domain?</Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Choose whether you want to automatically generate and assign self-signed PEM certificates
        for your custom domain.
      </StackItem>
      <StackItem>
        <AutomaticManualDecision {...props} />
      </StackItem>
    </Stack>
  );
};
