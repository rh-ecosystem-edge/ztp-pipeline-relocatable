import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { PasswordSelector } from './PasswordSelector';

export const PasswordPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('password'), [setActiveStep]);
  const {
    state: { password, passwordValidation: validation },
  } = useWizardProgressContext();

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
