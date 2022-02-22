import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { SshPublicKeySelector } from './SshPublicKeySelector';

export const SshPublicKeyPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('sshkey'), [setActiveStep]);
  const {
    state: { sshPubKeyValidation: validation },
  } = useWizardProgressContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<SshPublicKeySelector />}
        bottom={<WizardFooter back="domain" next="persist" isNextEnabled={() => !validation} />}
      />
    </Page>
  );
};
