import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DomainCertificates } from './DomainCertificates';
import { useK8SStateContext } from '../K8SStateContext';

export const DomainCertificatesPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  // No special step for that
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);
  const { customCertsValidation } = useK8SStateContext();

  // Keep enabled for self-signed certs
  const isNextEnabled = () =>
    Object.values(customCertsValidation).every(
      (validation) => validation.certValidated !== 'error' && validation.keyValidated !== 'error',
    );

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DomainCertificates />}
        bottom={
          <WizardFooter back="domaincertsdecision" next="sshkey" isNextEnabled={isNextEnabled} />
        }
      />
    </Page>
  );
};
