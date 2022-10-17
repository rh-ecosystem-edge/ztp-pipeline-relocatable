import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

// import { WelcomePage } from './components';
// import { Wizard } from './components/Wizard';
// import { Settings } from './components/Settings';
// import { K8SStateContextProvider } from './components/K8SStateContext';

import Redirect from './components/Redirect';
import { Layer3Page } from './components/Layer3Page/Layer3Page';
import { IngressPage } from './components/IngressPage';

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
        <Route path="/layer3" element={<Layer3Page />} />
        <Route path="/ingress" element={<IngressPage />} />
        <Route path="*" element={<Redirect to="/layer3" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
