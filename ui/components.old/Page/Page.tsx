import React from 'react';
import { BackgroundImage, PageHeader } from '@patternfly/react-core';

import { HeaderTools } from './HeaderTools';

import RedHatLogo from './RedHatLogo.svg';
import './Page.css';

const HeaderMiddlePart: React.FC = () => (
  <div className="page-header-middle">Edge cluster setup</div>
);

export const Page: React.FC = ({ children }) => {
  return (
    <>
      <BackgroundImage src={'/background.png'} />

      <PageHeader
        logo={<img src={RedHatLogo} alt="Logo" />}
        headerTools={<HeaderTools />}
        topNav={<HeaderMiddlePart />}
        className="page-header"
      />

      <div className="page-container">
        <div className="page-content">{children}</div>
      </div>
    </>
  );
};
