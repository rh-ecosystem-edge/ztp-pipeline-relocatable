import React from 'react';
import {
  Alert,
  AlertVariant,
  Button,
  ButtonVariant,
  Modal,
  ModalVariant,
  Tooltip,
} from '@patternfly/react-core';

import { getSecret } from '../../resources/secret';
import { delay } from '../utils';
import { isKubeAdmin } from '../../resources/oauth';
import { UIError } from '../types';

import { deleteKubeAdmin } from './persist';
import { KubeadminSecret } from '../constants';

type DeleteKubeadminModalProps = {
  isOpen: boolean;
  onClose: () => void;
};

const DeleteKubeadminModal: React.FC<DeleteKubeadminModalProps> = ({
  isOpen,
  onClose: _onClose,
}) => {
  const [error, setError] = React.useState<UIError>();
  const [message, setMessage] = React.useState<UIError>();
  const [inProgress, setInProgress] = React.useState(false);

  const onClose = () => {
    setError(undefined);
    setMessage(undefined);
    setInProgress(false);

    _onClose();
  };

  const onDelete = async () => {
    setError(undefined);
    setInProgress(true);

    if (await deleteKubeAdmin(setError)) {
      setMessage({
        title: 'Success',
        message: 'The kubeadmin user account was removed. You can close this dialog.',
      });
    }

    setInProgress(false);
  };

  return (
    <Modal
      variant={ModalVariant.small}
      title="Delete the kubeadmin user"
      isOpen={isOpen}
      onClose={onClose}
      actions={[
        <Button
          key="confirm"
          variant={ButtonVariant.danger}
          onClick={onDelete}
          isDisabled={inProgress || !!message}
        >
          Confirm
        </Button>,
        <Button key="cancel" variant={ButtonVariant.link} onClick={onClose}>
          {message ? 'Close' : 'Cancel'}
        </Button>,
      ]}
    >
      Do you want the kubeadmin user account to be deleted?
      <br />
      This action can not be undone.
      {error && (
        <Alert title={error.title} variant={AlertVariant.warning} isInline>
          {error.message}
        </Alert>
      )}
      {message && (
        <Alert title={message.title} variant={AlertVariant.success} isInline>
          {message.message}
        </Alert>
      )}
    </Modal>
  );
};

export const DeleteKubeadminButton: React.FC<{ className: string }> = ({ className }) => {
  const [kubeadminDisabledReason, setKubeadminDisabledReason] = React.useState<string | undefined>(
    // the button is disabled by default
    'Loading',
  );
  const [isOpen, setOpen] = React.useState(false);
  const [retryCounter, setRetryCounter] = React.useState(1);

  React.useEffect(() => {
    const doItAsync = async () => {
      setKubeadminDisabledReason('Loading');
      try {
        await getSecret(KubeadminSecret).promise;
      } catch (e) {
        setKubeadminDisabledReason('The kubeadmin account has already been deleted.');
        return;
      }

      const kubeadmin = await isKubeAdmin();
      if (kubeadmin) {
        setKubeadminDisabledReason(
          'You are logged in as kubeadmin. Use another cluster-admin account to delete kubeadmin user.',
        );
        return;
      }

      if (kubeadmin === undefined) {
        // TODO: check roles...
        setKubeadminDisabledReason(
          'Kubeadmin can be deleted only by an user with cluster-admin role.',
        );

        // try it again
        console.info('Failed to load username, retrying in a few seconds.');
        await delay(5000);
        setRetryCounter(retryCounter + 1);

        return;
      }

      setKubeadminDisabledReason(undefined);
    };

    doItAsync();
  }, [isOpen, retryCounter /* On every modal close */]);

  const isDisabled = !!kubeadminDisabledReason;

  return (
    <>
      <Tooltip content={kubeadminDisabledReason} trigger={isDisabled ? undefined : 'none'}>
        <Button
          data-testid="settings-page-button-delete-kubeadmin"
          variant={ButtonVariant.danger}
          onClick={() => setOpen(true)}
          isAriaDisabled={isDisabled}
          className={className}
        >
          Delete kubeadmin
        </Button>
      </Tooltip>
      <DeleteKubeadminModal isOpen={isOpen} onClose={() => setOpen(false)} />
    </>
  );
};
