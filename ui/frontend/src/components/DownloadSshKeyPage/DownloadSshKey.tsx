import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Grid,
  GridItem,
  Stack,
  StackItem,
  Title,
} from '@patternfly/react-core';
import { DownloadIcon } from '@patternfly/react-icons';
import { saveAs } from 'file-saver';

import { getSecret } from '../../resources/secret';
import {
  SSH_PRIVATE_KEY_SECRET,
  SSH_PRIVATE_KEY_SECRET_INCORRECT,
  SSH_PRIVATE_KEY_SECRET_TITLE,
} from '../PersistPage/constants';
import { PersistErrorType } from '../PersistPage/types';
import { workaroundUnmarshallObject } from '../../test-utils';

import book from './book.svg';
import './DownloadSshKey.css';

export const DownloadSshKey: React.FC<{ setDownloaded: (isDownloaded: boolean) => void }> = ({
  setDownloaded,
}) => {
  const [sshKey, setSshKey] = React.useState<string>();
  const [error, setError] = React.useState<PersistErrorType>(/* undefined */);

  React.useEffect(() => {
    const doItAsync = async () => {
      try {
        let secret = await getSecret(SSH_PRIVATE_KEY_SECRET).promise;
        secret = workaroundUnmarshallObject(secret);
        const data = secret?.data;

        if (data?.['id_rsa.key']) {
          setSshKey(data['id_rsa.key']);
        } else {
          setError({
            title: SSH_PRIVATE_KEY_SECRET_INCORRECT,
            message: 'The secret with ssh private key does not meet the required structure.',
          });
        }
      } catch (e) {
        console.error(e);
        setError({
          title: SSH_PRIVATE_KEY_SECRET_TITLE,
          message:
            'Downloading the SSH key failed. You will not be able to SSH into the cluster nodes.',
        });

        // Do not let the user stuck in case of error
        setDownloaded(true);
      }
    };

    if (!sshKey && !error) {
      doItAsync();
    }
  }, [sshKey, error, setDownloaded]);

  const onDownload = () => {
    if (sshKey) {
      const blob = new Blob([atob(sshKey)], { type: 'text/plain;charset=utf-8' });
      saveAs(blob, 'id_rsa.key'); // the private key
      setDownloaded(true);
    }
  };

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Alert
          variant={AlertVariant.warning}
          isInline
          title="Edge cluster does not store the private key. Please download and keep your key in a safe place."
        />
        {error?.title && (
          <Alert
            variant={AlertVariant.danger}
            title={
              <>
                {error.title}{' '}
                <Button variant={ButtonVariant.link} onClick={() => setError(undefined)} isInline>
                  Try again
                </Button>
              </>
            }
            isInline
            className="download-item__error"
          ></Alert>
        )}
      </StackItem>
      <StackItem>
        <Title headingLevel="h1">Download your private SSH key</Title>
      </StackItem>
      <StackItem className="wizard-sublabel">
        Your account will be granted access to all the nodes.
      </StackItem>
      <StackItem className="download-item">
        <Grid>
          <GridItem span={2} rowSpan={2} className="download-item__icon">
            <img src={book} className="download-ssh__book" alt="Book icon" />
          </GridItem>
          <GridItem span={10}>
            <div className="download-item__text">Edge Cluster Private SSH Key</div>
          </GridItem>
          <GridItem span={10}>
            <Button
              data-testid="button-download-ssh-key"
              variant={ButtonVariant.link}
              onClick={onDownload}
              isDisabled={!sshKey}
            >
              <DownloadIcon />
              &nbsp;Download
            </Button>
          </GridItem>
        </Grid>
      </StackItem>
    </Stack>
  );
};
