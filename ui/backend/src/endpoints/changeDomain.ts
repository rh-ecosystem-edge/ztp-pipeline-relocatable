import { Request, Response } from 'express';
import { ZTPFW_NAMESPACE, ZTPFW_UI_ROUTE_PREFIX } from '../constants';
import { DNS_NAME_REGEX, PatchType, ComponentRoute, Route } from '../frontend-shared';
import { getToken, PostResponse, unauthorized } from '../k8s';
import { ApiServerSpec, patchApiServerConfig } from '../resources/apiserver';
import { getIngressConfig, patchIngressConfig } from '../resources/ingress';
import { getAllRoutes, patchRoute } from '../resources/route';
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

    logger.debug(
      'Will update Ingress component route, hostname: ',
      domain,
      ', serving certificate: ',
      secretName,
    );
    return true;
  }

  return false;
};

const updateRoutes = async (
  token: string,
  _ingressDomain: string,
  _oldIngressDomain?: string,
): Promise<boolean> => {
  if (!_oldIngressDomain) {
    logger.info('Missing old Ingress domain - skipping update of Route resources.');
    return false;
  }
  const oldIngressDomain = `.${_oldIngressDomain}`;
  const ingressDomain = `.${_ingressDomain}`;
  logger.debug(`Updating all Route resources. From "${oldIngressDomain}" to "${ingressDomain}" wherever possible.`);

  try {
    const allRoutes = await getAllRoutes(token);
    if (!allRoutes?.length) {
      logger.error('Failed to retrieve list of all routes.');
      return false;
    }

    let promises: Promise<void>[] = [];
    allRoutes.forEach((route) => {
      if (route.spec?.host) {
        const newHost = route.spec.host.replace(oldIngressDomain, ingressDomain);
        if (newHost === route.spec.host) {
          logger.debug(
            `No change for the ${route.metadata.namespace}/${route.metadata.name} route, keeping host: "${newHost}".`,
          );
        } else {
          const patch: PatchType[] = [
            {
              op: 'replace',
              path: '/spec/host',
              value: newHost,
            },
          ];

          const patching = async () => {
            try {
              await patchRoute(
                token,
                { name: route.metadata.name || '', namespace: route.metadata.namespace || '' },
                patch,
              );
              logger.debug(
                `Route ${route.metadata.namespace}/${route.metadata.name} is patched, new host: ${newHost}`,
              );
            } catch (e) {
              logger.error(
                `Failed to patch ${route.metadata.namespace}/${route.metadata.name} route: `,
                e,
              );
            }
          };
          promises.push(patching());
        }
      } else {
        logger.debug(
          `Skipping update of ${route.metadata.namespace}/${route.metadata.name} route, missing host there.`,
        );
      }
    });

    await Promise.allSettled(promises);
  } catch (e) {
    logger.error('Failed to patch routes: ', e);
    return false;
  }
  return true;
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

  const oldIngressDomain = ingress.spec?.domain;
  const apiDomain = `api.${domain}`;
  const ingressDomain = `apps.${domain}`;

  if (ingressDomain === ingress?.spec?.domain) {
    logger.info(
      'Domain stays unchanged (based on the Ingress config), skipping persistence of it.',
    );
    res.writeHead(200).end(); // All good
    return;
  }
  logger.debug(
    `About to change domain from "${oldIngressDomain}" to "${ingressDomain}" (api: "${apiDomain}")`,
  );

  // Api
  const apiCertSecretName = await createSelfSignedTlsSecret(res, token, apiDomain, 'api-secret-');
  if (!apiCertSecretName) {
    return;
  }
  const namedCertificates = [
    // This is potentially buggy in case the ApiServer cluster has already namedCertificates present
    { names: [apiDomain], servingCertificate: { name: apiCertSecretName } },
  ];
  const apiServerPatches: { spec: ApiServerSpec } = {
    // We will merge in that case
    spec: {
      servingCerts: {
        namedCertificates,
      },
    },
  };

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

  // Keep going even if a route fails to be updated. To have at least something
  await updateRoutes(token, ingressDomain, oldIngressDomain);

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
    if (result.statusCode === 200) {
      logger.debug('Ingress config patched');
    } else {
      logger.info('Failed to patch Ingress cluster resource: ', result.body);
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
    logger.debug('ApiServer config patched');
    if (result.statusCode === 200) {
      logger.debug('ApiServer config patched');
    } else {
      logger.info('Failed to patch ApiServer cluster resource: ', result.body);
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
