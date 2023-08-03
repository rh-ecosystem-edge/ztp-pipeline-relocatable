import React from 'react';
// import { BackgroundImage, PageHeader } from '@patternfly/react-core';

// import RedHatLogo from './RedHatLogo.svg';
import './Page.css';

// const HeaderMiddlePart: React.FC = () => (
//     <div className="page-header-middle">Edge cluster setup</div>
// );

export const Page: React.FC = ({ children }) => (
  <div className="page-container">
    <div className="page-content">{children}</div>
  </div>
);

//   return (
//     <>
//       <PageHeader
//         logo={<img src={RedHatLogo} alt="Logo" />}
//         topNav={<HeaderMiddlePart />}
//         className="page-header"
//       />

//       <div className="page-container">
//         <div className="page-content">{children}</div>
//       </div>
//     </>
//   );
