import React from 'react';
import ReactDOM from 'react-dom';

import App from './App';
// import reportWebVitals from './reportWebVitals';
import { getBackendUrl } from './resources';

// import './index.css';
// import '@patternfly/patternfly/patternfly.css';
import '@patternfly/react-core/dist/styles/base.css';

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

console.log('UI Backend URL: ', getBackendUrl());
