import { FormGroup, StackItem } from '@patternfly/react-core';
import React from 'react';
import { AutomaticManualDecision } from '../DomainCertificatesDecisionPage/DomainCertificatesDecision';
import { DomainCertificatesPanel } from '../DomainCertificatesPage/DomainCertificatesPanel';
import { useSettingsPageContext } from './SettingsPageContext';

export const SettingsPageDomainCertificates: React.FC = () => {
  const { isCertificateAutomatic, setCertificateAutomatic } = useSettingsPageContext();
  React.useEffect(
    () => {
      /* TODO: decide about isutomatic */
    },
    [
      /* Just once */
    ],
  );

  const helperText = isCertificateAutomatic
    ? 'Choose whether you want to automatically generate and assign PEM certificates for your cluster domain.'
    : undefined;

  return (
    <>
      <StackItem className="summary-page-sumamary__item">
        <FormGroup
          fieldId="automatic"
          label="Domain certificate assignment"
          isRequired={true}
          helperText={helperText}
        >
          <AutomaticManualDecision
            isAutomatic={isCertificateAutomatic}
            setAutomatic={setCertificateAutomatic}
            id="automatic"
          />
        </FormGroup>
      </StackItem>
      {!isCertificateAutomatic && (
        <StackItem className="summary-page-sumamary__item">
          <DomainCertificatesPanel isSpaceItemsNone />
        </StackItem>
      )}
    </>
  );
};
