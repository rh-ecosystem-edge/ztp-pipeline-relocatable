import React from 'react';

import { Page } from '../Page';
import { ContentThreeRows } from '../ContentThreeRows';
import { WizardProgress, WizardStepType } from '../WizardProgress';
import { useWizardProgressContext } from '../WizardProgress/WizardProgressContext';
import { WizardFooter, WizardFooterProps } from '../WizardFooter';
import { DomainSelector } from './DomainSelector';
import { useK8SStateContext } from '../K8SStateContext';
import { validateDomainBackend } from './validateDomain';

export const DomainPage: React.FC = () => {
  const { setActiveStep } = useWizardProgressContext();
  const [isValidating, setIsValidating] = React.useState(false);
  React.useEffect(() => setActiveStep('domain'), [setActiveStep]);
  const {
    domainValidation: validation,
    domain,
    originalDomain,
    forceDomainValidation,
  } = useK8SStateContext();

  const onBeforeNext: WizardFooterProps['onBeforeNext'] = async () => {
    setIsValidating(true);

    const result =
      !domain ||
      (await validateDomainBackend((message) => {
        // Backend failed to pre-validate the domain (most probably the domain can not be resolved, the "dig" command failed)
        forceDomainValidation(message);
      }, domain));

    setIsValidating(false);

    // By returning false here, the transition to the next page as skipped
    return result;
  };

  let next: WizardStepType = 'sshkey';
  if (domain && domain !== originalDomain) {
    next = 'domaincertsdecision';
  }

  return (
    <Page>
      <ContentThreeRows
        top={<WizardProgress />}
        middle={<DomainSelector />}
        bottom={
          <WizardFooter
            back="ingressip"
            next={next}
            isNextEnabled={() => !domain || (!validation && !isValidating)}
            onBeforeNext={onBeforeNext}
          />
        }
      />
    </Page>
  );
};
