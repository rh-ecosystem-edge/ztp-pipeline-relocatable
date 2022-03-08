import React from 'react';

import { ExclamationCircleIcon } from '@patternfly/react-icons';
import { global_danger_color_100 as dangerColor } from '@patternfly/react-tokens';

export const HelperTextInvalid: React.FC<{ validation?: string }> = ({ validation }) =>
  validation ? (
    <div className="helper-text-invalid">
      <ExclamationCircleIcon color={dangerColor.value} />
      <span>{validation}</span>
    </div>
  ) : null;
