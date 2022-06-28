import React from 'react';
import { Stack, StackItem, Title } from '@patternfly/react-core';
import { DomainCertificatesPanel } from './DomainCertificatesPanel';

import './DomainCertificates.css';

export const DomainCertificates: React.FC = () => {
  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1" className="domain-certificate__h1">
          Upload your certificates
        </Title>
      </StackItem>
      <StackItem className="wizard-sublabel wizard-sublabel-dense">
        Secure your SSL/TLS routes with certificates in the PEM format.
      </StackItem>
      <StackItem className="wizard-sublabel wizard-sublabel-dense">
        If a certificate is not provided, a self-signed one will be automatically generated.
      </StackItem>
      <StackItem className="domain-certificate__item">
        <DomainCertificatesPanel isScrollable />
      </StackItem>
    </Stack>
  );
};
