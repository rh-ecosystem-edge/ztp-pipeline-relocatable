import React from 'react';

import { WizardProgressContextProvider } from '../WizardProgress';
import { useWizardState } from '../Wizard/wizardState';
import { Page } from '../Page';
import { ContentTwoCols } from '../ContentTwoCols';

import { SettingsPageLeft } from './SettingsPageLeft';
import { SettingsPageRight } from './SettingsPageRight';

export const Settings: React.FC = () => {
  const wizardState = useWizardState();

  return (
    <WizardProgressContextProvider state={wizardState}>
      <Page>
        <ContentTwoCols
          left={<SettingsPageLeft />}
          right={<SettingsPageRight isInitialEdit={false} />}
        />
      </Page>
    </WizardProgressContextProvider>
  );
};
