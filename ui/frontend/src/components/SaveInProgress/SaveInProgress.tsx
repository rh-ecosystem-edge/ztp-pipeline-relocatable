import React from 'react';
import { Bullseye, Flex, FlexItem, Spinner } from '@patternfly/react-core';

import WorkingOnHybridCloud from './WorkingOnHybridCloud.svg';

import './SaveInProgress.css';

export const SaveInProgress: React.FC = () => (
  <Bullseye>
    <Flex direction={{ default: 'column' }}>
      <FlexItem className="save-in-progress-item">
        <img src={WorkingOnHybridCloud} alt="Logo" />
      </FlexItem>
      <FlexItem className="save-in-progress-item">
        <h1>Saving configuration...</h1>
      </FlexItem>
      <FlexItem className="save-in-progress-item text-sublabel">
        This process may take a while. Do not unplug your computer from your edge device.
      </FlexItem>
      <FlexItem className="save-in-progress-item">
        <Spinner isSVG aria-label="Spinner - in progress" />
      </FlexItem>
    </Flex>
  </Bullseye>
);
