import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { WelcomePage } from './components';
import { Wizard } from './components/Wizard';
import { Settings } from './components/Settings';
import { K8SStateContextProvider } from './components/K8SStateContext';
import Redirect from './components/Redirect';

import './App.css';

function App() {
  return (
    <BrowserRouter>
      <K8SStateContextProvider>
        <Routes>
          {process.env.REACT_APP_BACKEND_PATH && (
            <>
              <Route
                path="/login/*"
                element={<Redirect to={process.env.REACT_APP_BACKEND_PATH} preservePathName />}
              />
            </>
          )}
          <Route path="/welcome" element={<WelcomePage />} />
          <Route path="/wizard/*" element={<Wizard />} />
          <Route path="/settings/*" element={<Settings />} />
          <Route path="*" element={<Redirect to="/welcome" />} />
        </Routes>
      </K8SStateContextProvider>
    </BrowserRouter>
  );
}

export default App;
