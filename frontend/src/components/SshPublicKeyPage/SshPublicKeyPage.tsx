import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { SshPublicKeySelector } from './SshPublicKeySelector';
import { useK8SStateContext } from '../K8SStateContext';

export const SshPublicKeyPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('sshkey'), [setActiveStep]);
  const { sshPubKeyValidation: validation } = useK8SStateContext();

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
