import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { ApiAddressSelector } from './ApiAddressSelector';

export const ApiAddressPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('apiaddr'), [setActiveStep]);

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<ApiAddressSelector />}
        bottom={<WizardFooter back={undefined} next="ingressip" />}
      />
    </Page>
  );
};
