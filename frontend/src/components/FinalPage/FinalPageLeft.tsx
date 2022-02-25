import React from 'react';

import kube from '../WelcomePage/kube.svg';
import ethernet from './ethernet.svg';

import './FinalPageLeft.css';

export const FinalPageLeft: React.FC = () => (
  <div
    className="final-page-left"
    style={{
      backgroundImage: 'url("/backgroundWelcome.png")',
    }}
  >
    <img src={kube} className="final-page-left__kube" alt="Kube" />
    <img src={ethernet} className="final-page-left__ethernet" alt="Kube" />
  </div>
);
