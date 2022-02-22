import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DomainSelector } from './DomainSelector';

export const DomainPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);
  const {
    state: { domainValidation: validation },
  } = useWizardProgressContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DomainSelector />}
        bottom={<WizardFooter back="ingressip" next="sshkey" isNextEnabled={() => !validation} />}
      />
    </Page>
  );
};
