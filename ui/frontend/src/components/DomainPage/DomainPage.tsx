import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress, WizardStepType } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DomainSelector } from './DomainSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const DomainPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);
  const { domainValidation: validation, domain, originalDomain } = useK8SStateContext();

  let next: WizardStepType = 'sshkey';
  if (domain !== originalDomain) {
    next = 'domaincertsdecision';
  }

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DomainSelector />}
        bottom={<WizardFooter back="ingressip" next={next} isNextEnabled={() => !validation} />}
      />
    </Page>
  );
};
