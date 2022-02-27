import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { PasswordSelector } from './PasswordSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const PasswordPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('password'), [setActiveStep]);
  const { password, passwordValidation: validation } = useK8SStateContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<PasswordSelector />}
        bottom={
          <WizardFooter
            back="username"
            next="apiaddr"
            isNextEnabled={() => !!password && !validation}
          />
        }
      />
    </Page>
  );
};
