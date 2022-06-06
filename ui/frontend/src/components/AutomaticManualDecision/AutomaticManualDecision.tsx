import React from 'react';
import { Radio, Split, SplitItem } from '@patternfly/react-core';

export type AutomaticManualDecisionProps = {
  id?: string;
  isAutomatic: boolean;
  setAutomatic: (isAutomatic: boolean) => void;

  labelAutomatic?: string;
  labelManual?: string;
};

/* TODO: Share this component with the Custom DOmain Certificates patch once merged this or another */
export const AutomaticManualDecision: React.FC<AutomaticManualDecisionProps> = ({
  id = 'automanual-decision',
  isAutomatic,
  setAutomatic,
  labelAutomatic = 'Automatic',
  labelManual = 'Manual',
}) => (
  <Split hasGutter id={id}>
    {/* TODO: Improve positioning on the Wizard's page */}
    <SplitItem>
      <Radio
        data-testid={`${id}__automatic`}
        id={`${id}__automatic`}
        label={labelAutomatic}
        name="automatic"
        isChecked={isAutomatic}
        onChange={() => setAutomatic(true)}
      />
    </SplitItem>
    <SplitItem>
      <Radio
        data-testid={`${id}__automatic`}
        id={`${id}__automatic`}
        label={labelManual}
        name="manual"
        isChecked={!isAutomatic}
        onChange={() => setAutomatic(false)}
      />
    </SplitItem>
  </Split>
);
