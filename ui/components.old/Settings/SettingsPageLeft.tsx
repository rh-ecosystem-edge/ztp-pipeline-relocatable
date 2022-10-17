import React from 'react';

import kube from '../WelcomePage/kube.svg';

import './SettingsPageLeft.css';

export const SettingsPageLeft: React.FC = () => (
  <div
    className="settings-page-left"
    style={{
      backgroundImage: 'url("/backgroundWelcome.png")',
    }}
  >
    <img src={kube} className="settings-page-left__kube" alt="Kube" />
  </div>
);
