import { cloneDeep } from 'lodash';
import { createResource, postRequest } from '../../resources';
import { getApiServerConfig } from '../../resources/apiserver';
import { ComponentRoute, getIngressConfig } from '../../resources/ingress';

import { Secret } from '../../resources/secret';
import {
  PERSIST_DOMAIN,
  RESOURCE_CREATE_TITLE,
  TLS_SECRET_NAMESPACE,
  ZTPFW_UI_ROUTE_PREFIX,
} from './constants';
import { TLS_SECRET } from './resourceTemplates';
import { PersistErrorType, TlsCertificate } from './types';

const generateCertificate = async ({
  setError,
  domain,
}: {
  setError: (error: PersistErrorType) => void;
  domain: string;
}): Promise<TlsCertificate | undefined> => {
  try {
    const certificate = (await postRequest('/generateCertificate', {
      domain,
    }).promise) as TlsCertificate;
    if (!certificate?.['tls.crt']) {
      console.error('Can not generate self-signed certificate');
      setError({
        title: RESOURCE_CREATE_TITLE,
        message: `Can not create self-signed certificate for the "${domain}" domain.`,
      });
      return undefined;
    }

    console.log('Remove me. Generated certificate: ', certificate);
    return certificate;
  } catch (e) {
    console.error(e);
    setError({
      title: PERSIST_DOMAIN,
      message: `Failed to generate certificate for "${domain}" domain.`,
    });
  }

  return undefined;
};

const createCertSecret = async (
  setError: (error: PersistErrorType) => void,
  namePrefix: string,
  certificate: TlsCertificate,
): Promise<Secret | undefined> => {
  try {
    const object = cloneDeep(TLS_SECRET);
    object.data = certificate;

    return createResource(object).promise;
  } catch (e) {
    console.error('Can not create resource: ', e);
    setError({
      title: RESOURCE_CREATE_TITLE,
      message: `Can not create ${namePrefix} TLS secret in the ${TLS_SECRET.metadata.namespace} namespace.`,
    });
  }
  return undefined;
};

const createSelfSignedTlsSecret = async (
  setError: (error: PersistErrorType) => void,
  domain: string,
  namePrefix: string,
): Promise<string | undefined> => {
  const certificate = await generateCertificate({
    setError,
    domain,
  });
  if (!certificate) {
    return undefined;
  }

  const certSecret = await createCertSecret(setError, namePrefix, certificate);
  if (!certSecret) {
    return undefined;
  }

  return certSecret.metadata.name;
};

const updateIngressComponentRoutes = async (
  setError: (error: PersistErrorType) => void,
  componentRoutes: ComponentRoute[],
  // Following type will not be hardcoded forever, the ZTPFW hostname might varry over different deployments
  routeName: 'console' | 'oauth-openshift' | 'edge-cluster-setup',
  domain: string,
  namePrefix: string,
) => {
  const secretName = await createSelfSignedTlsSecret(setError, domain, namePrefix);
  if (secretName) {
    const route = componentRoutes.find((r) => r.name === routeName);
    if (route) {
      // modify input argument
      route.hostname = domain;
      route.servingCertKeyPairSecret.name = secretName;
    } else {
      console.info(
        `Ingress resource does not contain record for the "${routeName}", adding new one to: `,
        componentRoutes,
      );
      componentRoutes.push({
        hostname: domain,
        name: routeName,
        namespace: TLS_SECRET_NAMESPACE,
        servingCertKeyPairSecret: {
          name: secretName,
        },
      });
    }
  }

  return componentRoutes;
};

// https://issues.redhat.com/browse/MGMT-9524
export const persistDomain = async (
  setError: (error: PersistErrorType) => void,
  domain?: string,
): Promise<boolean> => {
  if (!domain) {
    console.info('Domain change not requested, so skipping that step.');
    return true; // skip
  }

  const ingress = await getIngressConfig().promise;
  const apiServer = await getApiServerConfig().promise;

  const apiDomain = `api.${domain}`;
  const ingressDomain = `apps.${domain}`;

  if (ingressDomain === ingress.spec?.domain) {
    console.info('Domain stays unchanged, skipping persistence of it.');
    return true; // skip
  }

  /* TODO: avoid auto-generating of self-signed certificates if the user has provided them */

  // Api
  const apiCertSecretName = await createSelfSignedTlsSecret(setError, apiDomain, 'api-secret-');
  const namedCertificates = [
    // This is potentially buggy in case the ApiServer cluster has already namedCertificates present
    { names: [apiDomain], servingCertificate: { name: apiCertSecretName } },
  ];
  const apiServerPatches = [
    {
      op: apiServer.spec?.servingCerts?.namedCertificates ? 'replace' : 'add',
      path: '/spec/servingCerts/namedCertificates',
      value: namedCertificates,
    },
  ];

  // Ingress
  const consoleDomain = `console-openshift-console.${ingressDomain}`;
  const oauthDomain = `oauth-openshift.${ingressDomain}`;
  const ztpfwDomain = `${ZTPFW_UI_ROUTE_PREFIX}.${ingressDomain}`;

  let componentRoutes = ingress?.spec?.componentRoutes || [];
  componentRoutes = await updateIngressComponentRoutes(
    setError,
    componentRoutes,
    'console',
    consoleDomain,
    'console-secret-',
  );
  componentRoutes = await updateIngressComponentRoutes(
    setError,
    componentRoutes,
    'oauth-openshift',
    oauthDomain,
    'oauth-secret-',
  );
  componentRoutes = await updateIngressComponentRoutes(
    setError,
    componentRoutes,
    ZTPFW_UI_ROUTE_PREFIX,
    ztpfwDomain,
    'ztpfw-secret-',
  );
  // TODO: Anything else??

  const ingressPatches = [
    {
      op: ingress?.spec?.domain ? 'replace' : 'add',
      path: '/spec/domain',
      value: ingressDomain,
    },
    {
      op: ingress?.spec?.componentRoutes ? 'replace' : 'add',
      path: '/spec/componentRoutes',
      value: componentRoutes,
    },
  ];

  // Persist the changes (patch)
  console.log('TODO: call patch on apiServer: ', apiServerPatches);
  console.log('TODO: call patch on ingress: ', ingressPatches);
  return true;
};
