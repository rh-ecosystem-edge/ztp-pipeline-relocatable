import React from 'react';
import { Progress, ProgressVariant } from '@patternfly/react-core';

type PersistProgressProps = {
  className?: string;
  progress: number;
  progressError: boolean;
  label?: string;
};

let persistStepsCount = 1;
export const PersistSteps = {
  // Important: keep following steps aligned with actual order in persist()
  PersistIDP: persistStepsCount++,
  ReconcilePersistIDP: persistStepsCount++,

  SaveIngress: persistStepsCount++,
  ReconcileSaveIngress: persistStepsCount++,

  SaveApi: persistStepsCount++,
  ReconcileSaveApi: persistStepsCount++,

  PersistDomain: persistStepsCount++,
  ReconcilePersistDomain: persistStepsCount++,

  ReconcileUIPod: persistStepsCount++,
  ReconcileApiOperator: persistStepsCount++,
  ReconcileAuthOperator: persistStepsCount++,
};
persistStepsCount--;

const PersistStepLabels: string[] = [];
PersistStepLabels[PersistSteps.PersistIDP] = 'Saving identity provider';
PersistStepLabels[PersistSteps.ReconcilePersistIDP] =
  'Waiting for the identity provider to be added';
PersistStepLabels[PersistSteps.SaveIngress] = 'Saving Ingress IP';
PersistStepLabels[PersistSteps.ReconcileSaveIngress] = 'Waiting for the Ingress IP reconciliation';
PersistStepLabels[PersistSteps.SaveApi] = 'Saving API IP';
PersistStepLabels[PersistSteps.ReconcileSaveApi] = 'Waiting for the API IP to reconcile';
PersistStepLabels[PersistSteps.PersistDomain] = 'Saving domain change';
PersistStepLabels[PersistSteps.ReconcilePersistDomain] = 'Waiting for the domain to reconcile';
PersistStepLabels[PersistSteps.ReconcileUIPod] = 'Final waiting for the configuration pod';
PersistStepLabels[PersistSteps.ReconcileApiOperator] = 'Final waiting for the API operator';
PersistStepLabels[PersistSteps.ReconcileAuthOperator] =
  'Final waiting for the authentication operator';

export type UsePersistProgressType = {
  progress: number;
  setProgress: (stepFinished: number) => void;
};

export const usePersistProgress = (): UsePersistProgressType => {
  const [state, setProgressValue] = React.useState<{ progress: number; label?: string }>({
    progress: 0,
    label: undefined,
  });

  const setProgress = React.useCallback(
    (stepFinished: number) => {
      setProgressValue({
        progress: (stepFinished / persistStepsCount) * 100,
        label: PersistStepLabels[stepFinished + 1],
      });
    },
    [setProgressValue],
  );

  return React.useMemo(
    () => ({
      setProgress,
      ...state,
    }),
    [state, setProgress],
  );
};

export const PersistProgress: React.FC<PersistProgressProps> = ({
  className,
  progress,
  label,
  progressError,
}) => {
  let variant: ProgressVariant | undefined = undefined;
  if (progress === persistStepsCount) {
    variant = ProgressVariant.success;
  }
  if (progressError) {
    variant = ProgressVariant.danger;
  }

  return (
    <Progress
      id="persist-progress"
      className={className}
      value={progress}
      variant={variant}
      title="Persisting changes"
      label={label}
    />
  );
};
