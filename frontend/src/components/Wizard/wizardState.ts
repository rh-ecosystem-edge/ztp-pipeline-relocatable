import React from 'react';

import { IpTripletSelectorValidationType } from '../types';
import {
  domainValidator,
  ipTripletAddressValidator,
  passwordValidator,
  sshPubKeyValidator,
  usernameValidator,
} from '../utils';

import { WizardStateType } from './types';

export const useWizardState = (): WizardStateType => {
  const [username, setUsername] = React.useState('');
  const [usernameValidation, setUsernameValidation] = React.useState<string>('');
  const handleSetUsername = React.useCallback(
    (newVal: string) => {
      setUsernameValidation(usernameValidator(newVal));
      setUsername(newVal);
    },
    [setUsername],
  );

  const [password, setPassword] = React.useState('');
  const [passwordValidation, setPasswordValidation] = React.useState<string>('');
  const handleSetPassword = React.useCallback(
    (newVal: string) => {
      setPasswordValidation(passwordValidator(newVal));
      setPassword(newVal);
    },
    [setPassword],
  );

  const [apiaddr, setApiaddr] = React.useState('192168  7200');
  const [apiaddrValidation, setApiaddrValidation] = React.useState<IpTripletSelectorValidationType>(
    {
      valid: true,
      triplets: [],
    },
  );
  const handleSetApiaddr = React.useCallback(
    (newIp: string) => {
      setApiaddrValidation(ipTripletAddressValidator(newIp));
      setApiaddr(newIp);
    },
    [setApiaddr],
  );

  const [ingressIp, setIngressIp] = React.useState('192168  7201');
  const [ingressIpValidation, setIngressIpValidation] =
    React.useState<IpTripletSelectorValidationType>({
      valid: true,
      triplets: [],
    });
  const handleSetIngressIp = React.useCallback(
    (newIp: string) => {
      setIngressIpValidation(ipTripletAddressValidator(newIp));
      setIngressIp(newIp);
    },
    [setIngressIp],
  );

  const [domain, setDomain] = React.useState<string>('');
  const [domainValidation, setDomainValidation] =
    React.useState<WizardStateType['domainValidation']>();
  const handleSetDomain = React.useCallback((newDomain: string) => {
    setDomainValidation(domainValidator(newDomain));
    setDomain(newDomain);
  }, []);

  const [sshPubKey, setSshPubKey] = React.useState<string>('');
  const [sshPubKeyValidation, setSshPubKeyValidation] =
    React.useState<WizardStateType['sshPubKeyValidation']>();
  const handleSetSshPubKey = React.useCallback((newKey: string | File) => {
    const keyString = newKey as string;
    setSshPubKeyValidation(sshPubKeyValidator(keyString));
    setSshPubKey(keyString);
  }, []);

  return {
    username,
    usernameValidation,
    handleSetUsername,

    password,
    passwordValidation,
    handleSetPassword,

    apiaddr,
    apiaddrValidation,
    handleSetApiaddr,

    ingressIp,
    ingressIpValidation,
    handleSetIngressIp,

    domain,
    domainValidation,
    handleSetDomain,

    sshPubKey,
    handleSetSshPubKey,
    sshPubKeyValidation,
  };
};
