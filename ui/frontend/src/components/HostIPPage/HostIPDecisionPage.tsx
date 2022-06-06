import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress, WizardStepType } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter } from '../WizardFooter';
import { HostIPDecision } from './HostIPDecision';

export const HostIPDecisionPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  React.useEffect(() => setActiveStep('hostips'), [setActiveStep]);

  const [isAutomatic, setAutomatic] = React.useState<boolean>(
    () => true /* TODO: implement this initial state ! */,
  );

  let next: WizardStepType = 'apiaddr';
  if (!isAutomatic) {
    next = 'staticips';
  }

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<HostIPDecision isAutomatic={isAutomatic} setAutomatic={setAutomatic} />}
        bottom={<WizardFooter back="password" next={next} isNextEnabled={() => true} />}
      />
    </Page>
  );
};
