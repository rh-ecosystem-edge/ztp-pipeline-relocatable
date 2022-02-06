import React from 'react';
import { Routes, Route } from 'react-router';

import { WelcomePage, SubnetPage } from '../../components';
import Redirect from '../../Redirect';
import {
  WizardProgressContextData,
  WizardProgressContextProvider,
} from '../WizardProgress/WizardProgressContext';

export const Wizard: React.FC = () => {
  const wizardProgress: WizardProgressContextData = {
    steps: {
      subnet: {
        isCurrent: true,
        variant: 'info',
      },
      virtualip: {
        isCurrent: false,
        variant: 'pending',
      },
      domain: {
        isCurrent: false,
        variant: 'pending',
      },
      sshkey: {
        isCurrent: false,
        variant: 'pending',
      },
    },
  };

  return (
    <WizardProgressContextProvider value={wizardProgress}>
      <Routes>
        <Route path="/welcome" element={<WelcomePage />} />
        <Route path="/subnet" element={<SubnetPage />} />
        <Route path="*" element={<Redirect to="/wizard/welcome" />} />
      </Routes>
    </WizardProgressContextProvider>
  );
};
