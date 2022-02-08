import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';

import { VirtualIpSelector } from './VirtualIpSelector';

// TODO: https://marvelapp.com/prototype/hfd719b/screen/84707949/handoff
export const VirtualIpPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('virtualip'));

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<VirtualIpSelector />}
        bottom={<WizardFooter back="subnet" next="domain" />}
      />
    </Page>
  );
};
