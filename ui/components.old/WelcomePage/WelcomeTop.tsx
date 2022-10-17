import React from 'react';

import kube from './kube.svg';
import './WelcomeTop.css';

export const WelcomeTop: React.FC = () => (
  <div
    className="welcome-top"
    style={{
      backgroundImage: 'url("/backgroundWelcome.png")',
    }}
  >
    <img src={kube} className="welcome-top__kube" alt="Kube" />
  </div>
);
