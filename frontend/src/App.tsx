import React from 'react';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { WelcomePage } from './components';
import Redirect from './Redirect';

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
        <Route path="*" element={<WelcomePage />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
