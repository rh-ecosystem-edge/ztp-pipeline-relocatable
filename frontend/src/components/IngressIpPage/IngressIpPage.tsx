import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';

import { IngressIpSelector } from './IngressIpSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const IngressIpPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('ingressip'));
  const { ingressIp, ingressIpValidation } = useK8SStateContext();

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
