import React from 'react';
import {
  Button,
  ButtonVariant,
  Stack,
  StackItem,
  Text,
  TextVariants,
  Title,
} from '@patternfly/react-core';
import { CheckCircleIcon, ArrowRightIcon } from '@patternfly/react-icons';
import { global_success_color_100 as successColor } from '@patternfly/react-tokens';
import { useNavigate } from 'react-router-dom';

import { useConsoleUrl } from '../../resources/consoleUrl';
import { useK8SStateContext } from '../K8SStateContext';

import './FinalPageSummary.css';

export const FinalPageSummary: React.FC = () => {
  const navigate = useNavigate();
  const consoleUrl = useConsoleUrl();
  const state = useK8SStateContext();

  return (
    <Stack hasGutter className="final-page-sumamary">
      <StackItem className="final-page-sumamary__item-first">
        <Title headingLevel="h1">
          <CheckCircleIcon
            color={successColor.value}
            className="final-page-summary__icon-success"
          />
          Setup complete!
        </Title>
        <Text component={TextVariants.small}>
          Your cluster has been successfully configured and is ready to use.
        </Text>
      </StackItem>
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h3">Enjoy your Edge cluster</Title>
        <Text component={TextVariants.small}>
          Your cluster has been successfully configured and is ready to use.
        </Text>
      </StackItem>
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h3">Need to change something?</Title>
        <Text component={TextVariants.small}>
          If you need to modify your settings, make sure you are still connected to your edge
          cluster and click Settings.
        </Text>
      </StackItem>
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h3">Delete the kubeadmin user</Title>
        <Text component={TextVariants.small}>
          For security reasons, it is highly recommended to remove the kubeadmin user. To do so,
          relogin as the <b>{state.username}</b> user and click <b>Delete kubeadmin</b> button on
          the Settings page.
        </Text>
      </StackItem>
      <StackItem>
        <Button
          variant={ButtonVariant.primary}
          isDisabled={!consoleUrl}
          data-testid="final-page-button-console"
          onClick={() => {
            console.info('Redirecting to OCP console: ', consoleUrl);
            window.location.href = consoleUrl || '';
          }}
        >
          OpenShift console
        </Button>
        <Button
          variant={ButtonVariant.link}
          data-testid="final-page-button-settings"
          onClick={() => navigate(`/settings`)}
        >
          <Text className="final-page-summary__settings">
            Settings&nbsp;
            <ArrowRightIcon />
          </Text>
        </Button>
      </StackItem>
    </Stack>
  );
};
