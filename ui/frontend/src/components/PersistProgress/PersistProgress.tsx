import React from 'react';
import { Progress, ProgressVariant } from '@patternfly/react-core';

type PersistProgressProps = {
  progress: number;
  progressError: boolean;
};

let persistStepsCount = 1;
export const PersistSteps = {
  // Important: keep following steps aligned with actual order in persist()
  PersistIDP: persistStepsCount++,
  SaveIngress: persistStepsCount++,
  SaveApi: persistStepsCount++,
  PersistDomain: persistStepsCount++,

  ReconcileUIPod: persistStepsCount++,
  ReconcileApiOperator: persistStepsCount++,
  ReconcileAuthOperator: persistStepsCount++,
};
persistStepsCount--;

const PersistStepLabels: string[] = [];
PersistStepLabels[PersistSteps.PersistIDP] = 'Saving identity provider';
PersistStepLabels[PersistSteps.SaveIngress] = 'Saving Ingress IP';
PersistStepLabels[PersistSteps.SaveApi] = 'Saving API IP';
PersistStepLabels[PersistSteps.PersistDomain] = 'Saving domain change';
PersistStepLabels[PersistSteps.ReconcileUIPod] = 'Waiting for the configuration pod';
PersistStepLabels[PersistSteps.ReconcileApiOperator] = 'Waiting for the API operator';
PersistStepLabels[PersistSteps.ReconcileAuthOperator] = 'Waiting for the outhentication operator';

export type UsePersistProgressType = {
  progress: number;
  setProgress: (stepFinished: number) => void;
};

export const usePersistProgress = (): UsePersistProgressType => {
  const [progress, setProgressValue] = React.useState(0);

  const setProgress = React.useCallback(
    (stepFinished: number) => {
      setProgressValue((stepFinished / persistStepsCount) * 100);
    },
    [setProgressValue],
  );

  return React.useMemo(
    () => ({
      progress,
      setProgress,
    }),
    [progress, setProgress],
  );
};

export const PersistProgress: React.FC<PersistProgressProps> = ({ progress, progressError }) => {
  let variant: ProgressVariant | undefined = undefined;
  if (progress === persistStepsCount) {
    variant = ProgressVariant.success;
  }
  if (progressError) {
    variant = ProgressVariant.danger;
  }

  return (
    <Progress
      value={progress}
      variant={variant}
      title="Reconciling"
      label={PersistStepLabels[progress + 1] || ''}
    />
  );
};
