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

import './FinalPageSummary.css';

export const FinalPageSummary: React.FC = () => {
  const navigate = useNavigate();
  const consoleUrl = useConsoleUrl();

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
          Your Kuberame has been successfully configured and is ready to use.
        </Text>
      </StackItem>
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h3">Enjoy your KubeFrame</Title>
        <Text component={TextVariants.small}>
          MAC Your Kuberame has been successfully configured and is ready to use.
        </Text>
      </StackItem>
      <StackItem className="final-page-sumamary__item">
        <Title headingLevel="h3">Need to change something?</Title>
        <Text component={TextVariants.small}>
          If you need to modify your settings, make sure you are still connected to your KubeFrame
          and click Settings.
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
