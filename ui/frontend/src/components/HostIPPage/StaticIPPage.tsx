import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { StaticIPs } from './StaticIPs';
import { useK8SStateContext } from '../K8SStateContext';

export const StaticIPPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  const { hosts } = useK8SStateContext();

  // No special step for that
  React.useEffect(() => setActiveStep('hostips'), [setActiveStep]);

  const isNextEnabled = () => {
    const failedHost = hosts.find(
      (h) =>
        h.dnsValidation ||
        h.interfaces.find(
          (intf) => !!intf.ipv4.address?.validation || !!intf.ipv4.address?.gatewayValidation,
        ),
    );
    return !failedHost;
  };

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<StaticIPs isEdit />}
        bottom={<WizardFooter back="hostips" next="apiaddr" isNextEnabled={isNextEnabled} />}
      />
    </Page>
  );
};
