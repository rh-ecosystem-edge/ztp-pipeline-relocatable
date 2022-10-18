import React from 'react';
import { Bullseye, Flex, FlexItem, Spinner, Text, TextContent } from '@patternfly/react-core';

// TODO: Change the picture
import SittingGuyPict from '../BasicLayout/RedHatLogo.svg';

import './SaveInProgress.css';

export const SaveInProgress: React.FC = () => (
  <Bullseye>
    <Flex direction={{ default: 'column' }}>
      <FlexItem className="save-in-progress-item">
        <img src={SittingGuyPict} alt="Logo" />
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
