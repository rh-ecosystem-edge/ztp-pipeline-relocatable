import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { DownloadSshKey } from './DownloadSshKey';

export const DownloadSshKeyPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('sshkey'), [setActiveStep]);
  const [isDownloaded, setDownloaded] = React.useState(false);

  const isNextEnabled = () => isDownloaded;

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DownloadSshKey setDownloaded={setDownloaded} />}
        bottom={<WizardFooter back="domain" next="persist" isNextEnabled={isNextEnabled} />}
      />
    </Page>
  );
};
