import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { ApiAddressSelector } from './ApiAddressSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const ApiAddressPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  const { apiaddr, apiaddrValidation, handleSetApiaddr } = useK8SStateContext();

  React.useEffect(() => setActiveStep('apiaddr'), [setActiveStep]);

  React.useEffect(
    () => handleSetApiaddr(apiaddr),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [
      // force revalidation when entering the page (i.e. after Go Back)
    ],
  );

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<ApiAddressSelector />}
        bottom={
          <WizardFooter
            back="password"
            next="ingressip"
            isNextEnabled={() => !!apiaddr.trim() && apiaddrValidation.valid}
          />
        }
      />
    </Page>
  );
};
