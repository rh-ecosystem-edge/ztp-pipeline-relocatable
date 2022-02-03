import React from 'react';
import { BackgroundImage, PageHeader } from '@patternfly/react-core';

import RedHatLogo from './RedHatLogo.svg';
import './Page.css';

export const Page: React.FC = ({ children }) => {
  return (
    <>
      <BackgroundImage src={'/background.png'} />

      <PageHeader logo={<img src={RedHatLogo} alt="Logo" className="logo" />} />

      <div className="page-container">
        <div className="page-content">{children}</div>
      </div>
    </>
  );
};
