import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';

import { IngressIpSelector } from './IngressIpSelector';

export const IngressIpPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('ingressip'));
  const {
    state: { ingressIp, ingressIpValidation },
  } = useWizardProgressContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<IngressIpSelector />}
        bottom={
          <WizardFooter
            back="apiaddr"
            next="domain"
            isNextEnabled={() => !!ingressIp.trim() && ingressIpValidation.valid}
          />
        }
      />
    </Page>
  );
};
