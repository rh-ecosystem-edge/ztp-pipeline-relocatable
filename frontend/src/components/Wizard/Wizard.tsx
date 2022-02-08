import React from 'react';
import { Routes, Route } from 'react-router';

import { WelcomePage, SubnetPage, VirtualIpPage } from '../../components';
import Redirect from '../../Redirect';
import { WizardProgressContextProvider } from '../WizardProgress';

import './Wizard.css';

export const Wizard: React.FC = () => {
  return (
    <WizardProgressContextProvider>
      <Routes>
        <Route path="/welcome" element={<WelcomePage />} />
        <Route path="/subnet" element={<SubnetPage />} />
        <Route path="/virtualip" element={<VirtualIpPage />} />
        <Route path="*" element={<Redirect to="/wizard/welcome" />} />
      </Routes>
    </WizardProgressContextProvider>
  );
};
