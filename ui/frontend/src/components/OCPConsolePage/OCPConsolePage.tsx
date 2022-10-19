import React from 'react';
import {
  Button,
  ClipboardCopy,
  FormGroup,
  Spinner,
  Text,
  TextContent,
  TextVariants,
} from '@patternfly/react-core';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { useConsoleUrl } from '../../resources/consoleUrl';
import { loadIngressData } from '../IngressPage/dataLoad';
import { UIError } from '../types';

import Circles from './circles.svg';
import OCPLogo from './Logo-Red_Hat-OCP.svg';

import './OCPConsolePage.css';

export const OCPConsolePage = () => {
  const [error, setError] = React.useState<UIError>();
  const [etcHostsRecord, setEtcHostsRecord] = React.useState<string>();
  const consoleUrl = useConsoleUrl();

  const onNavigateToConsole = () => {
    if (consoleUrl) {
      window.location.href = consoleUrl;
    }
  };

  React.useEffect(
    () => {
      const doItAsync = async () => {
        const ingressIp = await loadIngressData({ setError });
        const domainName = 'TODO-read-domain-name';

        if (ingressIp && domainName) {
          setEtcHostsRecord(`${ingressIp} ${domainName}`);
        }
      };

      doItAsync();
    },
    [
      /* Just once */
    ],
  );

  return (
    <Page>
      <BasicLayout error={error}>
        <ContentSection>
          <TextContent>
            <Text component={TextVariants.h1}>One more thing</Text>
            <Text className="text-sublabel">
              Update your hosts file to access your Red Hat OpenShift Container Platform console.
            </Text>
          </TextContent>
          <br />
          {!etcHostsRecord && <Spinner size="sm" />}
          {etcHostsRecord && (
            <FormGroup fieldId="etc-hosts" label="Add this line to your /etc/hosts file">
              <ClipboardCopy
                id="etc-hosts"
                isReadOnly
                hoverTip="Copy"
                clickTip="Copied"
                className="console-page__etc-hosts"
              >
                {etcHostsRecord}
              </ClipboardCopy>
            </FormGroup>
          )}
        </ContentSection>

        <ContentSection className="console-page__main-section">
          <div className="console-page__main-section-logo-with-button">
            <img src={OCPLogo} alt="Red Hat OCP Logo" />
            <Button onClick={onNavigateToConsole} isDisabled={!consoleUrl}>
              Go to console
            </Button>
          </div>

          <img src={Circles} alt="Circles" className="console-page__main-section-circles" />
        </ContentSection>
      </BasicLayout>
    </Page>
  );
};
