import { Request, Response } from 'express';
import { ZTPFW_NAMESPACE, ZTPFW_UI_ROUTE_PREFIX } from '../constants';
import { DNS_NAME_REGEX, PatchType, ComponentRoute } from '../frontend-shared';
import { getToken, unauthorized } from '../k8s';
import { getApiServerConfig, patchApiServerConfig } from '../resources/apiserver';
import { getIngressConfig, patchIngressConfig } from '../resources/ingress';
import { createCertSecret, generateCertificate } from './generateCertificate';

import { validateInput } from './utils';

const logger = console;

const createSelfSignedTlsSecret = async (
  res: Response,
  token: string,
  domain: string,
  namePrefix: string,
): Promise<string | undefined> => {
  const certificate = await generateCertificate(res, domain);
  if (!certificate) {
    return undefined;
  }

  const certSecret = await createCertSecret(res, token, namePrefix, certificate);
  if (!certSecret) {
    return undefined;
  }

  return certSecret.metadata.name;
};

const updateIngressComponentRoutes = async (
  res: Response,
  token: string,
  componentRoutes: ComponentRoute[],
  // Following type will not be hardcoded forever, the ZTPFW hostname might varry over different deployments
  routeName: 'console' | 'oauth-openshift' | 'edge-cluster-setup',
  domain: string,
  namePrefix: string,
  routeNamespace: string,
): Promise<boolean> => {
  const secretName = await createSelfSignedTlsSecret(res, token, domain, namePrefix);
  if (secretName) {
    const route = componentRoutes.find((r) => r.name === routeName);
    if (route) {
      // modify input argument
      route.hostname = domain;
      route.servingCertKeyPairSecret.name = secretName;
    } else {
      componentRoutes.push({
        hostname: domain,
        name: routeName,
        namespace: routeNamespace,
        servingCertKeyPairSecret: {
          name: secretName,
        },
      });
    }

    return true;
  }

  return false;
};

const changeDomainImpl = async (res: Response, token: string, _domain?: string): Promise<void> => {
  const domain = validateInput(DNS_NAME_REGEX, _domain);
  logger.debug('ChangeDomain endpoint called, domain:', domain);

  if (!domain) {
    res.writeHead(422).end();
    return;
  }

  /* TODO: avoid auto-generating of self-signed certificates if the user has provided them */

  const ingress = await getIngressConfig(token);
  const apiServer = await getApiServerConfig(token);

  const apiDomain = `api.${domain}`;
  const ingressDomain = `apps.${domain}`;

  if (ingressDomain === ingress?.spec?.domain) {
    console.info('Domain stays unchanged, skipping persistence of it.');
    res.writeHead(200).end(); // All good
    return;
  }

  // Api
  const apiCertSecretName = await createSelfSignedTlsSecret(res, token, apiDomain, 'api-secret-');
  if (!apiCertSecretName) {
    return;
  }
  const namedCertificates = [
    // This is potentially buggy in case the ApiServer cluster has already namedCertificates present
    { names: [apiDomain], servingCertificate: { name: apiCertSecretName } },
  ];
  const apiServerPatches: PatchType[] = [
    {
      op: apiServer.spec?.servingCerts?.namedCertificates ? 'replace' : 'add',
      path: '/spec/servingCerts/namedCertificates',
      value: namedCertificates,
    },
  ];

  logger.debug('Remove me: going on Ingress now');
  // Ingress
  const consoleDomain = `console-openshift-console.${ingressDomain}`;
  const oauthDomain = `oauth-openshift.${ingressDomain}`;
  const ztpfwDomain = `${ZTPFW_UI_ROUTE_PREFIX}.${ingressDomain}`;

  const componentRoutes = ingress?.spec?.componentRoutes || [];
  if (
    !(
      (
        (await updateIngressComponentRoutes(
          res,
          token,
          componentRoutes,
          'console',
          consoleDomain,
          'console-secret-',
          'openshift-console', // namespace
        )) &&
        (await updateIngressComponentRoutes(
          res,
          token,
          componentRoutes,
          'oauth-openshift',
          oauthDomain,
          'oauth-secret-',
          'openshift-authentication',
        )) &&
        (await updateIngressComponentRoutes(
          res,
          token,
          componentRoutes,
          ZTPFW_UI_ROUTE_PREFIX,
          ztpfwDomain,
          'ztpfw-secret-',
          ZTPFW_NAMESPACE,
        ))
      )
      // TODO: Anything else??
    )
  ) {
    logger.info('Update of an ingress component route failed, exiting.');
    return;
  }

  const ingressPatches: PatchType[] = [
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
  try {
    const result = await patchIngressConfig(token, ingressPatches);
    if (result.statusCode !== 200) {
      res
        .writeHead(
          result.statusCode,
          `Failed to patch Ingress cluster resource: ${result.body?.message || ''}`,
        )
        .end();
    }
  } catch (e) {
    res.writeHead(500, 'Failed to patch Ingress cluster resource.').end();
    return;
  }

  try {
    const result = await patchApiServerConfig(token, apiServerPatches);
    logger.debug('Patched ApiServer result: ', result);
    if (result.statusCode !== 200) {
      res
        .writeHead(
          result.statusCode,
          `Failed to patch ApiServer cluster resource: ${result.body?.message || ''}`,
        )
        .end();
    }
  } catch (e) {
    res.writeHead(500, 'Failed to patch ApiServer cluster resource.').end();
    return;
  }

  res.writeHead(200).end(); // All good
};

// https://issues.redhat.com/browse/MGMT-9524
export function changeDomain(req: Request, res: Response): void {
  logger.debug('ChangeDomain endpoint called');
  const token = getToken(req);
  if (!token) return unauthorized(req, res);

  // no need to register server middleware just for that
  const body: Buffer[] = [];
  req
    .on('data', (chunk: Buffer) => {
      body.push(chunk);
    })
    .on('end', async () => {
      try {
        const data: string = Buffer.concat(body).toString();
        const encoded = JSON.parse(data) as { domain?: string };
        await changeDomainImpl(res, token, encoded?.domain);
      } catch (e) {
        logger.error('Failed to parse input for changeDomain');
        res.writeHead(422).end();
      }
    });
}
