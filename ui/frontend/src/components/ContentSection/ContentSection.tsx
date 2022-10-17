import React from 'react';
import { Panel, PanelMain, PanelMainBody } from '@patternfly/react-core';

import './ContentSection.css';

export const ContentSection: React.FC = ({ children }) => {
  return (
    <Panel className="content-section">
      <PanelMain>
        <PanelMainBody>{children}</PanelMainBody>
      </PanelMain>
    </Panel>
  );
};
