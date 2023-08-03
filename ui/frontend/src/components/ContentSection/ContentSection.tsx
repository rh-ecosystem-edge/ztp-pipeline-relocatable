import React from 'react';
import { Panel, PanelMain, PanelMainBody } from '@patternfly/react-core';

import './ContentSection.css';

export const ContentSection: React.FC<{ className?: string }> = ({ className = '', children }) => {
  return (
    <Panel className={`content-section ${className}`}>
      <PanelMain>
        <PanelMainBody>{children}</PanelMainBody>
      </PanelMain>
    </Panel>
  );
};
