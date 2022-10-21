import React from 'react';
import { TextContent, TextVariants, Text, Button } from '@patternfly/react-core';
import { saveAs } from 'file-saver';

import { BasicLayout } from '../BasicLayout';
import { ContentSection } from '../ContentSection';
import { Page } from '../Page';
import { UIError } from '../types';
import { getSecret } from '../../resources/secret';
import { SSH_PRIVATE_KEY_SECRET } from '../constants';
import { workaroundUnmarshallObject } from '../../test-utils';
import { DownloadIcon } from '@patternfly/react-icons';

export const SshKeyPage = () => {
  const [error, setError] = React.useState<UIError>();
  const [sshKey, setSshKey] = React.useState<string>();

  React.useEffect(
    () => {
      const doItAsync = async () => {
        try {
          let secret = await getSecret(SSH_PRIVATE_KEY_SECRET).promise;
          secret = workaroundUnmarshallObject(secret);
          const data = secret?.data;

          if (data?.['id_rsa.key']) {
            setSshKey(data['id_rsa.key']);
          } else {
            setError({
              title: 'Incorrect SSH key secret',
              message: 'The secret with ssh private key does not meet the required structure.',
            });
          }
        } catch (e) {
          console.error(e);
          setError({
            title: 'Missing SSH private key',
            message:
              'Downloading the SSH key failed. Without the key, you will not be able to SSH into the cluster nodes.',
          });
        }
      };

      doItAsync();
    },
    [
      /* Only once */
    ],
  );

  const onDownload = () => {
    if (sshKey) {
      const blob = new Blob([atob(sshKey)], { type: 'text/plain;charset=utf-8' });
      saveAs(blob, 'id_rsa.key'); // the private key
    }
  };

  return (
    <Page>
      <BasicLayout
        error={error}
        warning={{
          title:
            'We do not store the private key. Please download and keep your key in a safe place.',
        }}
      >
        <ContentSection>
          <TextContent>
            <Text component={TextVariants.h1}>SSH key</Text>
            <Text className="text-sublabel">
              Your account will be granted access to all the nodes.
            </Text>
          </TextContent>
          <br />
          <Button onClick={onDownload} isDisabled={!sshKey}>
            <DownloadIcon />
            &nbsp;Download SSH key
          </Button>
        </ContentSection>
      </BasicLayout>
    </Page>
  );
};
