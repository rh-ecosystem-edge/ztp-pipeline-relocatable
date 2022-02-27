import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { Wizard } from './components/Wizard';
import { Settings } from './components/Settings';
import Redirect from './Redirect';

import './App.css';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        {process.env.REACT_APP_BACKEND_PATH && (
          <>
            <Route
              path="/login/*"
              element={<Redirect to={process.env.REACT_APP_BACKEND_PATH} preservePathName />}
            />
            {/* TODO: Implement landing page after logout */}
            <Route
              path="/logout/*"
              element={<Redirect to={process.env.REACT_APP_BACKEND_PATH} preservePathName />}
            />
          </>
        )}
        <Route path="/wizard/*" element={<Wizard />} />
        <Route path="/settings/*" element={<Settings />} />
        <Route path="*" element={<Redirect to="/wizard/welcome" />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
