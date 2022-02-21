import React from 'react';

import { IpSelectorValidationType } from '../IpSelector';
import { domainValidator, ipAddressValidator, sshPubKeyValidator } from '../utils';

import { WizardStateType } from './types';

export const useWizardState = (): WizardStateType => {
  const [apiaddr, setApiaddr] = React.useState('            '); // TODO: set default here
  const [apiaddrValidation, setApiaddrValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });
  const handleSetApiaddr = React.useCallback(
    (newApiaddr: string) => {
      setApiaddrValidation(ipAddressValidator(newApiaddr, true));
      setApiaddr(newApiaddr);
    },
    [setApiaddr],
  );

  const [ingressIp, setIngressIp] = React.useState('            ');
  const [ingressIpValidation, setIngressIpValidation] = React.useState<IpSelectorValidationType>({
    valid: true,
    digits: [],
  });
  const handleSetIngressIp = React.useCallback(
    (newIp: string) => {
      setIngressIpValidation(ipAddressValidator(newIp, false));
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
