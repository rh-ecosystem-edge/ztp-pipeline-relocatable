import React from 'react';

import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';

export const HelperTextInvalid: React.FC<{ id: string; validation?: string }> = ({
  id,
  validation,
}) =>
  validation ? (
    <div className="helper-text-invalid">
      <ExclamationCircleIcon color={dangerColor.value} />
      <span data-testid={id}>{validation}</span>
    </div>
  ) : null;
