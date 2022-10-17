import React from 'react';
import {
  Button,
  ButtonVariant,
  Divider,
  Flex,
  FlexItem,
  Stack,
  StackItem,
} from '@patternfly/react-core';
import { PowerOffIcon } from '@patternfly/react-icons';
import { Sidebar, SidebarContent, SidebarPanel } from '@patternfly/react-core';

import { Navigation } from '../Navigation';

import RedHatLogo from './RedHatLogo.svg';
import cloudyCircles from './cloudyCircles.svg';

import './BasicLayout.css';

export const BasicLayout: React.FC = ({ children }) => {
  return (
    <Sidebar tabIndex={0}>
      <SidebarPanel variant="sticky" width={{ default: 'width_25' }} className="basic-layout-left">
        <Flex direction={{ default: 'column' }}>
          <Flex justifyContent={{ default: 'justifyContentCenter' }}>
            <FlexItem>
              <img src={RedHatLogo} alt="Logo" />
            </FlexItem>
            <Divider
              orientation={{
                default: 'vertical',
              }}
            />
            <FlexItem alignSelf={{ default: 'alignSelfStretch' }}>
              <span className="basic-layout-title">Edge device setup</span>
            </FlexItem>
          </Flex>

          <Flex
            direction={{ default: 'column' }}
            justifyContent={{ default: 'justifyContentCenter' }}
            className="basic-layout-left-center"
            alignSelf={{ default: 'alignSelfCenter' }}
          >
            <img src={cloudyCircles} alt="Illustration" />
          </Flex>

          <Flex justifyContent={{ default: 'justifyContentCenter' }}>
            <Button className="basic-layout-logout basic-layout-bottom-row">
              <PowerOffIcon />
              &nbsp;Log out
            </Button>
          </Flex>
        </Flex>
      </SidebarPanel>

      <SidebarContent className="basic-layout-right">
        <Flex>
          <FlexItem>
            <Navigation />
          </FlexItem>
          <Divider
            orientation={{
              default: 'vertical',
            }}
          />

          <Flex justifyContent={{ default: 'justifyContentCenter' }} flex={{ default: 'flex_1' }}>
            <Stack hasGutter>
              <StackItem isFilled className="basic-layout-content">
                {children}
              </StackItem>
              <StackItem className="basic-layout-bottom-row">
                <Button>Save</Button>
                <Button variant={ButtonVariant.link}>Cancel</Button>
              </StackItem>
            </Stack>
          </Flex>
        </Flex>
      </SidebarContent>
    </Sidebar>
  );
};
