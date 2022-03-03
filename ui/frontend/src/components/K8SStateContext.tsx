import React from 'react';

import { IpTripletSelectorValidationType, K8SStateContextData } from './types';
import {
  domainValidator,
  ipTripletAddressValidator,
  ipWithoutDots,
  passwordValidator,
  usernameValidator,
} from './utils';

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
  const [passwordValidation, setPasswordValidation] = React.useState(true);
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
      handleSetUsername,
      ingressIp,
      ingressIpValidation,
      password,
      passwordValidation,
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
