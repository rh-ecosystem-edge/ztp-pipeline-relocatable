import { FormGroup, StackItem } from '@patternfly/react-core';
import React from 'react';
import { AutomaticManualDecision } from '../DomainCertificatesDecisionPage/DomainCertificatesDecision';
import { DomainCertificatesPanel } from '../DomainCertificatesPage/DomainCertificatesPanel';

export const SettingsPageDomainCertificates: React.FC = () => {
  const [isAutomatic, setAutomatic] = React.useState(true);

  React.useEffect(
    () => {
      /* TODO: decide about isutomatic */
    },
    [
      /* Just once */
    ],
  );

  return (
    <>
      <StackItem className="summary-page-sumamary__item">
        <FormGroup
          fieldId="automatic"
          label="Domain certificate assignment"
          isRequired={true}
          helperText="Choose whether or not you want to automatically assign certificates for your cluster domain."
        >
          <AutomaticManualDecision
            isAutomatic={isAutomatic}
            setAutomatic={setAutomatic}
            id="automatic"
          />
        </FormGroup>
      </StackItem>
      {!isAutomatic && (
        <StackItem className="summary-page-sumamary__item">
          <DomainCertificatesPanel />
        </StackItem>
      )}
    </>
  );
};
