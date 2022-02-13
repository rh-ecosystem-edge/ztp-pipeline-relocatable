import React from 'react';
import { Routes, Route } from 'react-router';

import { WelcomePage, SubnetPage, VirtualIpPage, DomainPage } from '../../components';
import Redirect from '../../Redirect';
import { WizardProgressContextProvider } from '../WizardProgress';

import { useWizardState } from './wizardState';

import './Wizard.css';
import { SshPublicKeyPage } from '../SshPublicKeyPage';

export const Wizard: React.FC = () => {
  const wizardState = useWizardState();

  return (
    <WizardProgressContextProvider state={wizardState}>
      <Routes>
        <Route path="/welcome" element={<WelcomePage />} />
        <Route path="/subnet" element={<SubnetPage />} />
        <Route path="/virtualip" element={<VirtualIpPage />} />
        <Route path="/domain" element={<DomainPage />} />
        <Route path="/sshkey" element={<SshPublicKeyPage />} />
        <Route path="/persist" element={/*<PersistPage />*/ <WelcomePage />} />
        <Route path="*" element={<Redirect to="/wizard/welcome" />} />
      </Routes>
    </WizardProgressContextProvider>
  );
};
