import React from 'react';
import { FileUpload, FormGroup, Stack, StackItem, Title } from '@patternfly/react-core';

import { useWizardProgressContext } from '../WizardProgress';
import { OptionalBadge } from '../Badge';

import './SshPublicKeySelector.css';

const fieldId = 'input-domain';

export const SshPublicKeySelector: React.FC = () => {
  const {
    state: { sshPubKey, handleSetSshPubKey, sshPubKeyValidation: validationMessage },
  } = useWizardProgressContext();

  const [filename, setFilename] = React.useState<string>();
  const [isFileUploading, setIsFileUploading] = React.useState(false);
  const [error, setError] = React.useState<string>();

  const validation = error || validationMessage;

  const dropzoneProps = {
    accept: '.pub',
    maxSize: 2048,
    onDropRejected: () => setError('File not supported.'),
  };

  return (
    <Stack className="wizard-content" hasGutter>
      <StackItem>
        <Title headingLevel="h1">SSH public key</Title>
      </StackItem>
      <StackItem>
        Want to use your SSH public key instead of a password to log into hosts? <OptionalBadge />
      </StackItem>
      <StackItem isFilled className="ssh-pub-key-item">
        <FormGroup
          fieldId={fieldId}
          helperTextInvalid={
            validation && <div className="validation-failed-text">{validation}</div>
          }
          validated={validation ? 'error' : 'default'}
        >
          <FileUpload
            id={fieldId}
            style={{ resize: 'vertical' }}
            validated={validation ? 'error' : 'default'}
            isRequired={false}
            type="text"
            value={sshPubKey}
            filename={filename}
            onChange={(value, filename) => {
              setFilename(filename);

              if (filename) {
                handleSetSshPubKey(((value || '') as string).trim());
              } else {
                handleSetSshPubKey(value);
              }
            }}
            onBlur={(e) => {
              handleSetSshPubKey((sshPubKey || '').trim());
            }}
            onReadStarted={() => setIsFileUploading(true)}
            onReadFinished={() => setIsFileUploading(false)}
            isLoading={isFileUploading}
            dropzoneProps={dropzoneProps}
            allowEditingUploadedText={true}
          />
        </FormGroup>
      </StackItem>
    </Stack>
  );
};
