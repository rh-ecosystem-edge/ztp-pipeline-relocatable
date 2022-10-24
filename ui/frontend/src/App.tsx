import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import Redirect from './components/Redirect';
import {
  URI_API,
  URI_CONSOLE,
  URI_CREDENTIALS,
  URI_DOMAIN,
  URI_INGRESS,
  URI_LAYER3,
  URI_SSHKEY,
} from './components/Navigation/routes';

import { Layer3Page } from './components/Layer3Page/Layer3Page';
import { IngressPage } from './components/IngressPage';
import { OCPConsolePage } from './components/OCPConsolePage';
import { APIPage } from './components/APIPage';
import { CredentialsPage } from './components/CredentialsPage';
import { SshKeyPage } from './components/SshKeyPage/SshKeyPage';
import { DomainPage } from './components/DomainPage/DomainPage';

import './App.css';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        {process.env.REACT_APP_BACKEND_PATH && (
          <Route
            path="/login/*"
            element={<Redirect to={process.env.REACT_APP_BACKEND_PATH} preservePathName />}
          />
        )}

        <Route path={URI_LAYER3} element={<Layer3Page />} />
        <Route path={URI_INGRESS} element={<IngressPage />} />
        <Route path={URI_API} element={<APIPage />} />
        <Route path={URI_DOMAIN} element={<DomainPage />} />
        <Route path={URI_CREDENTIALS} element={<CredentialsPage />} />
        <Route path={URI_SSHKEY} element={<SshKeyPage />} />
        <Route path={URI_CONSOLE} element={<OCPConsolePage />} />

        <Route path="*" element={<Redirect to={URI_INGRESS} />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
