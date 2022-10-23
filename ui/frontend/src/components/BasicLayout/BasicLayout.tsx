import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Divider,
  Flex,
  FlexItem,
  List,
  ListItem,
  Panel,
  PanelMain,
  Spinner,
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
import { useOperatorsReconciling } from '../operators';

export const BasicLayout: React.FC<{
  error?: UIError;
  warning?: UIError;
  onSave?: () => void;
  isValueChanged?: boolean;
  isSaving?: boolean;
  actions?: React.ReactNode[];
}> = ({ error, warning, isValueChanged, isSaving, onSave, actions = [], children }) => {
  const operatorsReconciling = useOperatorsReconciling();

  const isSaveButton = onSave !== undefined;
  const isOperatorReconciling =
    operatorsReconciling === undefined || operatorsReconciling.length > 0;

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
          <FlexItem className="basic-layout__navigation">
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
                <StackItem>
                  {error?.title && (
                    <Alert
                      variant={AlertVariant.danger}
                      isInline
                      title={error.title}
                      className="basic-layout__alert"
                    >
                      {error.message}
                    </Alert>
                  )}
                  {isOperatorReconciling && isSaveButton && (
                    <Alert
                      variant={AlertVariant.warning}
                      isInline
                      title="Operator reconciliation is in progress"
                      className="basic-layout__alert"
                    >
                      Saving changes is not possible until operators become ready. They are probably
                      reconciling after previous changes.
                      {operatorsReconciling !== undefined && (
                        <>
                          <br />
                          <List isPlain>
                            {operatorsReconciling.map((op) => (
                              <ListItem key="op.metadata.name">{op.metadata.name}</ListItem>
                            ))}
                          </List>
                        </>
                      )}
                    </Alert>
                  )}
                  {warning?.title && (
                    <Alert
                      variant={AlertVariant.warning}
                      isInline
                      title={warning.title}
                      className="basic-layout__alert"
                    >
                      {warning.message}
                    </Alert>
                  )}
                </StackItem>

                <StackItem isFilled className="basic-layout-content">
                  {children}
                </StackItem>
                <StackItem>
                  <Panel>
                    <PanelMain>
                      {isSaveButton && (
                        <Button onClick={onSave} isDisabled={!isValueChanged || isSaving}>
                          {isOperatorReconciling && (
                            <>
                              <Spinner size="sm" />
                              &nbsp;
                            </>
                          )}
                          Save
                        </Button>
                      )}

                      {isSaveButton && (
                        <Button
                          variant={ButtonVariant.link}
                          onClick={reloadPage}
                          isDisabled={!isValueChanged || isSaving || isOperatorReconciling}
                        >
                          Cancel
                        </Button>
                      )}
                      {actions}
                    </PanelMain>
                  </Panel>
                </StackItem>
              </Stack>
            </Flex>
          )}
        </Flex>
      </SidebarContent>
    </Sidebar>
  );
};
