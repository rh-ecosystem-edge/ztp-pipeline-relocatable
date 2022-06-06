import React from 'react';
import { Panel, PanelMain, PanelMainBody } from '@patternfly/react-core';

import { useK8SStateContext } from '../K8SStateContext';
import { HostStaticIP } from './HostStaticIP';

export const StaticIPsPanel: React.FC<{
  isScrollable?: boolean;
  isEdit?: boolean;
}> = ({ isScrollable, isEdit = true }) => {
  const { hosts, handleSetHost } = useK8SStateContext();

  const sortedHosts = hosts.sort((h1, h2) => {
    // First by role, control plane nodes first
    if (h1.role !== h2.role) {
      if (h1.role === 'control') {
        return -1;
      }
      return 1;
    }

    // Then by hostname
    return (h1.hostname || h1.nodeName).localeCompare(h2.hostname || h2.nodeName);
  });

  return (
    <Panel isScrollable={isScrollable} className="page-inner-panel">
      <PanelMain tabIndex={0}>
        <PanelMainBody>
          {sortedHosts.map((h, idx) => {
            // Assumption: hosts are sorted by "role", control planes first
            const isLeadingControlPlane = idx === 0;

            return (
              <HostStaticIP
                key={h.nodeName}
                host={h}
                handleSetHost={handleSetHost}
                isEdit={isEdit}
                isLeadingControlPlane={isLeadingControlPlane}
              />
            );
          })}
        </PanelMainBody>
      </PanelMain>
    </Panel>
  );
};
