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
import { kubeadminSecret, KUBEADMIN_REMOVE_OK } from '../PersistPage/constants';
import { deleteKubeAdmin } from '../PersistPage/persistIdentityProvider';
import { PersistErrorType } from '../PersistPage';
import { getBackendUrl, getRequest } from '../../resources';
import { delay } from '../utils';

type DeleteKubeadminModalProps = {
  isOpen: boolean;
  onClose: () => void;
};

const DeleteKubeadminModal: React.FC<DeleteKubeadminModalProps> = ({
  isOpen,
  onClose: _onClose,
}) => {
  const [error, setError] = React.useState<PersistErrorType>();
  const [message, setMessage] = React.useState<PersistErrorType>();
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
        title: KUBEADMIN_REMOVE_OK,
        message: 'The kubeadmin user account is removed now.',
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

const getUsername = () =>
  getRequest<{
    body: {
      username: string;
    };
    statusCode: number;
  }>(`${getBackendUrl()}/user`).promise;

export const DeleteKubeadminButton: React.FC = () => {
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
        await getSecret(kubeadminSecret).promise;
      } catch (e) {
        setKubeadminDisabledReason('The kubeadmin account has already been deleted.');
        return;
      }

      const name = (await getUsername())?.body?.username;

      if (name === 'kube:admin') {
        setKubeadminDisabledReason(
          'You are logged in as kubeadmin. Use another cluster-admin account to delete kubeadmin user.',
        );
        return;
      }

      if (!name) {
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
        >
          Delete kubeadmin
        </Button>
      </Tooltip>
      <DeleteKubeadminModal isOpen={isOpen} onClose={() => setOpen(false)} />
    </>
  );
};
