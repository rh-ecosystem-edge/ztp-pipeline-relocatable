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
import { SaveInProgress } from './components/SaveInProgress';
import { Layer3Page } from './components/Layer3Page/Layer3Page';
import { IngressPage } from './components/IngressPage';
import { OCPConsolePage } from './components/OCPConsolePage';

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

        {/* TODO: Replace SaveInProgress by actual implementation */}
        <Route path={URI_LAYER3} element={<Layer3Page />} />
        <Route path={URI_INGRESS} element={<IngressPage />} />
        <Route path={URI_API} element={<SaveInProgress />} />
        <Route path={URI_DOMAIN} element={<SaveInProgress />} />
        <Route path={URI_CREDENTIALS} element={<SaveInProgress />} />
        <Route path={URI_SSHKEY} element={<SaveInProgress />} />
        <Route path={URI_CONSOLE} element={<OCPConsolePage />} />

        <Route path="*" element={<Redirect to={URI_LAYER3} />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
