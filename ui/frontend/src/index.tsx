import '@patternfly/react-core/dist/styles/base.css';

import React from 'react';
import ReactDOM from 'react-dom';

import App from './App';
import { getBackendUrl } from './resources';
import { GIT_BUILD_SHA } from './sha';

import './index.css';

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root'),
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
// reportWebVitals();

// For debugging - especially after domain change
console.info('***** The Edgecluster UI version: ', GIT_BUILD_SHA);
console.log('UI Backend URL: ', getBackendUrl());
console.log('Frontend accessed at: ', window.location.href);
