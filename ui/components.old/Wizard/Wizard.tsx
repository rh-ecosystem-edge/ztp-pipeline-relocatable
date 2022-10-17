import React from 'react';
import { Routes, Route } from 'react-router';

import {
  UsernamePage,
  PasswordPage,
  ApiAddressPage,
  IngressIpPage,
  DomainPage,
  DomainCertificatesPage,
  DomainCertificatesDecisionPage,
  PersistPage,
  FinalPage,
} from '../../components';
import { DownloadSshKeyPage } from '../DownloadSshKeyPage';
import Redirect from '../Redirect';
import { WizardProgressContextProvider } from '../WizardProgress';

import './Wizard.css';

export const Wizard: React.FC = () => {
  return (
    <WizardProgressContextProvider>
      <Routes>
        <Route path="/username" element={<UsernamePage />} />
        <Route path="/password" element={<PasswordPage />} />
        <Route path="/apiaddr" element={<ApiAddressPage />} />
        <Route path="/ingressip" element={<IngressIpPage />} />
        <Route path="/domain" element={<DomainPage />} />
        <Route path="/domaincertsdecision" element={<DomainCertificatesDecisionPage />} />
        <Route path="/domaincertificates" element={<DomainCertificatesPage />} />
        <Route path="/sshkey" element={<DownloadSshKeyPage />} />
        <Route path="/persist" element={<PersistPage />} />
        <Route path="/final" element={<FinalPage />} />
        <Route path="*" element={<Redirect to="/welcome" />} />
      </Routes>
    </WizardProgressContextProvider>
  );
};
