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

import { navigateToNewDomain, persist } from './persist';
import { PersistErrorType } from './types';
import { useK8SStateContext } from '../K8SStateContext';
import { PersistProgress, usePersistProgress } from '../PersistProgress';

import './PersistPageBottom.css';

export const PersistPageBottom: React.FC = () => {
  const navigate = useNavigate();
  const [error, setError] = React.useState<PersistErrorType>(/* undefined */);
  const [retry, setRetry] = React.useState(true);
  const state = useK8SStateContext();
  const progress = usePersistProgress();

  React.useEffect(() => {
    if (!retry) {
      return;
    }
    setRetry(false);
    setError(undefined);

    persist(state, setError, progress.setProgress, () =>
      navigateToNewDomain(state.domain, '/wizard/final'),
    );
  }, [retry, setError, progress.setProgress, state]);

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
          <StackItem className="wizard-sublabel">
            Saving settings for your edge cluster...
          </StackItem>
          <StackItem isFilled width="100%">
            <PersistProgress
              className="persist-page-bottom__persist-progress"
              {...progress}
              progressError={!!error}
            />
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
          <StackItem className="wizard-sublabel">
            Settings succesfully saved, it might take several minutes for cluster to reconcile.
          </StackItem>
          <StackItem width="100%">
            <PersistProgress
              className="persist-page-bottom__persist-progress"
              {...progress}
              progressError={!!error}
            />
          </StackItem>
        </>
      )}
    </Stack>
  );
};
