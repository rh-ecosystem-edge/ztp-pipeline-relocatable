import React from 'react';

import { IpTripletSelectorValidationType } from './types';
import {
  domainValidator,
  ipTripletAddressValidator,
  ipWithoutDots,
  passwordValidator,
  usernameValidator,
} from './utils';

export type K8SStateContextData = {
  username: string;
  usernameValidation?: string; // just a message or empty
  handleSetUsername: (newVal: string) => void;

  password: string;
  passwordValidation?: string;
  handleSetPassword: (newVal: string) => void;

  apiaddr: string; // 12 characters
  apiaddrValidation: IpTripletSelectorValidationType;
  handleSetApiaddr: (newApiaddr: string) => void;

  ingressIp: string; // 12 characters
  ingressIpValidation: IpTripletSelectorValidationType;
  handleSetIngressIp: (newIp: string) => void;

  domain: string;
  handleSetDomain: (newDomain: string) => void;
  domainValidation?: string;
};

const K8SStateContext = React.createContext<K8SStateContextData | null>(null);

export const K8SStateContextProvider: React.FC<{
  children: React.ReactNode;
}> = ({ children }) => {
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

  const [apiaddr, setApiaddr] = React.useState(ipWithoutDots('192.168.7.200')); // 192168  7200
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

  const [ingressIp, setIngressIp] = React.useState(ipWithoutDots('192.168.7.201')); // 192168  7201
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
    React.useState<K8SStateContextData['domainValidation']>();
  const handleSetDomain = React.useCallback((newDomain: string) => {
    setDomainValidation(domainValidator(newDomain));
    setDomain(newDomain);
  }, []);

  const value = React.useMemo(
    () => ({
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

      // sshPubKey,
      // handleSetSshPubKey,
      // sshPubKeyValidation,
    }),
    [
      apiaddr,
      apiaddrValidation,
      domain,
      domainValidation,
      handleSetApiaddr,
      handleSetDomain,
      handleSetIngressIp,
      handleSetPassword,
      // handleSetSshPubKey,
      handleSetUsername,
      ingressIp,
      ingressIpValidation,
      password,
      passwordValidation,
      // sshPubKey,
      // sshPubKeyValidation,
      username,
      usernameValidation,
    ],
  );

  return <K8SStateContext.Provider value={value}>{children}</K8SStateContext.Provider>;
};

export const useK8SStateContext = () => {
  const context = React.useContext(K8SStateContext);
  if (!context) {
    throw new Error('useK8SStateContext must be used within K8SStateContextProvider.');
  }
  return context;
};
