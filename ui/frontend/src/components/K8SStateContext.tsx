import React from 'react';
import { isEqual } from 'lodash';

import {
  IpTripletSelectorValidationType,
  K8SStateContextData,
  K8SStateContextDataFields,
  CustomCertsValidationType,
} from './types';
import { ChangeDomainInputType, TlsCertificate } from '../copy-backend-common';
import {
  customCertsValidator,
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
  const [ingressIp, setIngressIp] = React.useState(ipWithoutDots('192.168.7.201')); // 192168  7201
  const [apiaddrValidation, setApiaddrValidation] = React.useState<IpTripletSelectorValidationType>(
    {
      valid: true,
      triplets: [],
    },
  );
  const handleSetApiaddr = React.useCallback(
    (newIp: string) => {
      setApiaddrValidation(ipTripletAddressValidator(newIp, ingressIp));
      setApiaddr(newIp);
    },
    [setApiaddr, ingressIp],
  );

  const [ingressIpValidation, setIngressIpValidation] =
    React.useState<IpTripletSelectorValidationType>({
      valid: true,
      triplets: [],
    });
  const handleSetIngressIp = React.useCallback(
    (newIp: string) => {
      setIngressIpValidation(ipTripletAddressValidator(newIp, apiaddr));
      setIngressIp(newIp);
    },
    [setIngressIp, apiaddr],
  );

  const [domain, setDomain] = React.useState<string>('');
  const [originalDomain, setOriginalDomain] = React.useState<string>();
  const [domainValidation, setDomainValidation] =
    React.useState<K8SStateContextData['domainValidation']>();
  const handleSetDomain = React.useCallback(
    (newDomain: string) => {
      setDomainValidation(domainValidator(newDomain));
      setDomain(newDomain);
      if (!originalDomain) {
        // Hint: This is expected to be called within initialDataLoad() only
        setOriginalDomain(newDomain);
      }
    },
    [originalDomain],
  );

  const [customCerts, setCustomCerts] = React.useState<ChangeDomainInputType['customCerts']>({});
  const [customCertsValidation, setCustomCertsValidation] =
    React.useState<CustomCertsValidationType>({});

  const setCustomCertificate = React.useCallback(
    (domain: string, certificate: TlsCertificate) => {
      const newCustomCerts = { ...customCerts };
      newCustomCerts[domain] = certificate;
      setCustomCerts(newCustomCerts);
      setCustomCertsValidation(customCertsValidator(customCertsValidation, domain, certificate));
    },
    [customCertsValidation, customCerts, setCustomCerts],
  );

  const isAllValid = React.useCallback(() => {
    const result =
      !usernameValidation &&
      passwordValidation &&
      apiaddrValidation.valid &&
      ingressIpValidation.valid &&
      !domainValidation &&
      !Object.keys(customCertsValidation).find(
        (d) =>
          customCertsValidation[d].certValidated === 'error' ||
          customCertsValidation[d].keyValidated === 'error',
      );
    return result;
  }, [
    apiaddrValidation.valid,
    customCertsValidation,
    domainValidation,
    ingressIpValidation.valid,
    passwordValidation,
    usernameValidation,
  ]);

  const fieldValues: K8SStateContextDataFields = React.useMemo(
    () => ({
      username,
      password,
      apiaddr,
      ingressIp,
      domain,
      originalDomain,
      customCerts,
    }),
    [username, password, apiaddr, ingressIp, domain, originalDomain, customCerts],
  );

  const [snapshot, setSnapshot] = React.useState<K8SStateContextDataFields>();
  const setClean = React.useCallback(() => {
    setSnapshot(fieldValues);
  }, [fieldValues]);
  const isDirty = React.useCallback((): boolean => {
    return !isEqual(fieldValues, snapshot);
  }, [fieldValues, snapshot]);

  const value = React.useMemo(
    () => ({
      ...fieldValues,

      isDirty,
      setClean,
      isAllValid,

      usernameValidation,
      handleSetUsername,

      passwordValidation,
      handleSetPassword,

      apiaddrValidation,
      handleSetApiaddr,

      ingressIpValidation,
      handleSetIngressIp,

      domainValidation,
      handleSetDomain,

      customCertsValidation,
      setCustomCertificate,
    }),
    [
      fieldValues,
      isDirty,
      setClean,
      isAllValid,
      usernameValidation,
      handleSetUsername,
      passwordValidation,
      handleSetPassword,
      apiaddrValidation,
      handleSetApiaddr,
      ingressIpValidation,
      handleSetIngressIp,
      domainValidation,
      handleSetDomain,
      customCertsValidation,
      setCustomCertificate,
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
