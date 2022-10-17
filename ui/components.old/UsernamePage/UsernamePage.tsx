import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { UsernameSelector } from './UsernameSelector';
import { useK8SStateContext } from '../K8SStateContext';

export const UsernamePage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('username'), [setActiveStep]);
  const { username, usernameValidation: validation } = useK8SStateContext();

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<UsernameSelector />}
        bottom={
          <WizardFooter
            back={undefined}
            next="password"
            isNextEnabled={() => !!username && !validation}
          />
        }
      />
    </Page>
  );
};
