import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress, WizardStepType } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DomainCertificatesDecision } from './DomainCertificatesDecision';
import { useK8SStateContext } from '../K8SStateContext';

export const DomainCertificatesDecisionPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  const { domainValidation: validation, customCerts } = useK8SStateContext();
  const [isAutomatic, setAutomatic] = React.useState<boolean>(
    () => Object.keys(customCerts || {}).length === 0,
  );

  // No special step for that
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);

  let next: WizardStepType = 'sshkey';
  if (!isAutomatic) {
    next = 'domaincertificates';
  }

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={
          <DomainCertificatesDecision isAutomatic={isAutomatic} setAutomatic={setAutomatic} />
        }
        bottom={<WizardFooter back="domain" next={next} isNextEnabled={() => !validation} />}
      />
    </Page>
  );
};
