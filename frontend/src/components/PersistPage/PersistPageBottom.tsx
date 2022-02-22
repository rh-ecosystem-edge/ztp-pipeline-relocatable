import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Stack,
  StackItem,
} from '@patternfly/react-core';
import { CheckCircleIcon, InProgressIcon } from '@patternfly/react-icons';
import {
  global_primary_color_light_100 as progressColor,
  global_success_color_100 as successColor,
} from '@patternfly/react-tokens';

import { useWizardProgressContext } from '../WizardProgress';
import { PeristsErrorType, persist } from './persist';

import './PersistPageBottom.css';

export const PersistPageBottom: React.FC = () => {
  const navigate = useNavigate();
  const [error, setError] = React.useState<PeristsErrorType>(/* undefined */);
  const [retry, setRetry] = React.useState(true);
  const { state } = useWizardProgressContext();

  React.useEffect(() => {
    if (!retry) {
      return;
    }
    setRetry(false);
    setError(undefined);
    persist(state, setError);
  }, [retry, setError, state]);

  return (
    <Stack className="persist-page-bottom" hasGutter>
      {error?.title ? (
        <>
          <StackItem isFilled className="persist-page-bottom__error-item">
            <Alert variant={AlertVariant.danger} title={error.title} isInline>
              {error.message}
            </Alert>
          </StackItem>
          <StackItem className="persist-page-bottom__error-item-footer">
            <div className="wizard-footer">
              <Button variant={ButtonVariant.primary} onClick={() => setRetry(true)}>
                Try again
              </Button>
              <Button variant={ButtonVariant.link} onClick={() => navigate(`/wizard/sshkey`)}>
                Go back
              </Button>
            </div>
          </StackItem>
        </>
      ) : error === undefined ? (
        <>
          <StackItem>
            <InProgressIcon
              color={progressColor.value}
              className="persist-page-bottom__progress-icon"
            />
          </StackItem>
          <StackItem isFilled className="wizard-sublabel">
            Saving settings for your KubeFrame...
          </StackItem>
        </>
      ) : (
        <>
          <StackItem>
            <CheckCircleIcon
              color={successColor.value}
              className="persist-page-bottom__success-icon"
            />
          </StackItem>
          <StackItem isFilled className="wizard-sublabel">
            Settings succesfully saved.
          </StackItem>
        </>
      )}
    </Stack>
  );
};
