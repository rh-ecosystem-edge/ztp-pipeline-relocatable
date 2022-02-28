import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DomainSelector } from './DomainSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const DomainPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);
  const { domainValidation: validation } = useK8SStateContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DomainSelector />}
        bottom={<WizardFooter back="ingressip" next="persist" isNextEnabled={() => !validation} />}
      />
    </Page>
  );
};
