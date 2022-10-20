import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Divider,
  Flex,
  FlexItem,
  Stack,
  StackItem,
  Text,
  TextContent,
  TextVariants,
} from '@patternfly/react-core';
import { PowerOffIcon } from '@patternfly/react-icons';
import { Sidebar, SidebarContent, SidebarPanel } from '@patternfly/react-core';

import { Navigation } from '../Navigation';
import { UIError } from '../types';
import { SaveInProgress } from '../SaveInProgress';
import { onLogout } from '../logout';
import { reloadPage } from '../utils';

import RedHatLogo from './RedHatLogo.svg';
import cloudyCircles from './cloudyCircles.svg';

import './BasicLayout.css';

export const BasicLayout: React.FC<{
  error?: UIError;
  onSave?: () => void;
  isValueChanged?: boolean;
  isSaving?: boolean;
  actions?: React.ReactNode[];
}> = ({ error, isValueChanged, isSaving, onSave, actions = [], children }) => {
  const isSaveButton = onSave !== undefined;

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
            <Button className="basic-layout-logout basic-layout-bottom-row" onClick={onLogout}>
              <PowerOffIcon />
              &nbsp;Log out
            </Button>
          </Flex>
        </Flex>
      </SidebarPanel>

      <SidebarContent className="basic-layout-right">
        <Flex>
          <FlexItem>
            <TextContent className="basic-layout__settings">
              <Text component={TextVariants.h1}>Settings</Text>
            </TextContent>

            <Navigation />
          </FlexItem>
          <Divider
            orientation={{
              default: 'vertical',
            }}
          />

          {isSaving && (
            <Flex
              justifyContent={{ default: 'justifyContentCenter' }}
              alignSelf={{ default: 'alignSelfStretch' }}
              flex={{ default: 'flex_1' }}
            >
              <Stack hasGutter>
                <StackItem isFilled className="basic-layout-content">
                  <SaveInProgress />
                </StackItem>
              </Stack>
            </Flex>
          )}

          {!isSaving && (
            <Flex justifyContent={{ default: 'justifyContentCenter' }} flex={{ default: 'flex_1' }}>
              <Stack hasGutter>
                {error?.title && (
                  <Alert variant={AlertVariant.danger} isInline title={error.title}>
                    {error.message}
                  </Alert>
                )}
                <StackItem isFilled className="basic-layout-content">
                  {children}
                </StackItem>

                <StackItem className="basic-layout-bottom-row">
                  {isSaveButton && (
                    <Button onClick={onSave} isDisabled={!isValueChanged || isSaving}>
                      Save
                    </Button>
                  )}

                  {isSaveButton && (
                    <Button
                      variant={ButtonVariant.link}
                      onClick={reloadPage}
                      isDisabled={!isValueChanged || isSaving}
                    >
                      Cancel
                    </Button>
                  )}
                  {actions}
                </StackItem>
              </Stack>
            </Flex>
          )}
        </Flex>
      </SidebarContent>
    </Sidebar>
  );
};
