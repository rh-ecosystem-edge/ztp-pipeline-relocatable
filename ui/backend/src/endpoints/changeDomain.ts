/* eslint-disable @typescript-eslint/restrict-template-expressions */
import { Request, Response } from 'express';
import {
  Route,
  ChangeDomainInputType,
  getApiDomain,
  getIngressDomain,
  TlsCertificate,
  getConsoleDomain,
  getOauthDomain,
  getZtpfwDomain,
  ZTPFW_UI_ROUTE_PREFIX,
  OAUTH_NAMESPACE,
  getClusterDomainFromComponentRoutes,
} from '../common';
import {
  ZTPFW_DEPLOYMENT_NAME,
  ZTPFW_NAMESPACE,
  ZTPFW_OAUTHCLIENT_NAME,
  ZTPFW_ROUTE_NAME,
} from '../constants';
import { DNS_NAME_REGEX, PatchType, ComponentRoute } from '../frontend-shared';
import { getToken, PostResponse, unauthorized } from '../k8s';
import { ApiServerSpec, patchApiServerConfig } from '../resources/apiserver';
import { getDeployment, patchDeployment } from '../resources/deployment';
import { getIngressConfig, patchIngressConfig } from '../resources/ingress';
import { getOAuthClient, patchOAuthClient } from '../resources/oauthclient';
import { backupRoute, getRoute, patchRoute } from '../resources/route';
import { createCertSecret, generateCertificate } from './generateCertificate';

import { validateInput } from './utils';

const logger = console;

const createTlsSecret = async (
  res: Response,
  token: string,
  domain: string,
  namePrefix: string,
  customCerts: ChangeDomainInputType['customCerts'] = {},
): Promise<string | undefined> => {
  let certificate: TlsCertificate | undefined = customCerts[domain];

  // if not provided, so generate self-signed one
  if (certificate) {
    logger.debug('Custom certificate provided for domain: ', domain);
  } else {
    certificate = await generateCertificate(res, domain);

    if (!certificate) {
      return undefined;
    }
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
  customCerts: ChangeDomainInputType['customCerts'],
  componentRoutes: ComponentRoute[],
  // Following type will not be hardcoded forever, the ZTPFW hostname might varry over different deployments
  routeName: 'console' | 'oauth-openshift' | 'edge-cluster-setup',
  domain: string,
  namePrefix: string,
  routeNamespace: string,
): Promise<string | undefined /* secretName */> => {
  logger.debug(`updateIngressComponentRoutes called for ${routeName} and domain ${domain}`);
  const secretName = await createTlsSecret(res, token, domain, namePrefix, customCerts);
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
  }

  return secretName;
};

const updateSingleRoute = async (
  token: string,
  ztpfwDomain: string,
  route: Route,
): Promise<PostResponse<Route> | void> => {
  if (route.spec?.host) {
    if (ztpfwDomain === route.spec.host) {
      logger.debug(
        `No change for the ${route.metadata.namespace}/${route.metadata.name} route, keeping host: "${route.spec.host}".`,
      );
    } else {
      const patch: PatchType[] = [
        {
          op: 'replace',
          path: '/spec/host',
          value: ztpfwDomain,
        },
      ];

      try {
        return patchRoute(
          token,
          { name: route.metadata.name || '', namespace: route.metadata.namespace || '' },
          patch,
        ).then((r) => {
          logger.debug(
            `Route ${route.metadata.namespace}/${route.metadata.name} is patched, new host: ${ztpfwDomain}`,
          );
          return r;
        });
      } catch (e) {
        logger.error(
          `Failed to patch ${route.metadata.namespace}/${route.metadata.name} route: `,
          e,
        );
      }
    }
  } else {
    logger.debug(
      `Skipping update of ${route.metadata.namespace}/${route.metadata.name} route, missing host there.`,
    );
  }
};

const updateOauthRedirectUri = async (token: string, ztpfwDomain: string): Promise<string> => {
  const newOauthRedirectUri = `https://${ztpfwDomain}/login/callback`;
  try {
    const oauthClient = await getOAuthClient(token, ZTPFW_OAUTHCLIENT_NAME);

    const redirectURIs = oauthClient.redirectURIs || [];
    if (!redirectURIs.includes(newOauthRedirectUri)) {
      logger.debug('Appending oauthclient for: ', newOauthRedirectUri);
      redirectURIs.push(newOauthRedirectUri);

      const patchesOauth: PatchType[] = [
        {
          op: oauthClient.redirectURIs ? 'replace' : 'add',
          path: '/redirectURIs',
          value: redirectURIs,
        },
      ];
      const result = await patchOAuthClient(token, ZTPFW_OAUTHCLIENT_NAME, patchesOauth);
      if (result.statusCode === 200) {
        logger.debug('ZTPFW UI OAuthClient patched: ');
      } else {
        logger.error('Failed to patch ZTPFW UI OAuth Client: ', result);
        // keep going
      }
    } else {
      logger.debug('OAuthclient already contains ', newOauthRedirectUri, ', skipping');
    }
  } catch (e) {
    logger.error('Failed to patch ZTPFW UI OAuthClient: ', e);
  }

  return newOauthRedirectUri;
};

const updateZtpfwDeployment = async (
  token: string,
  ztpfwDomain: string,
  newOauthRedirectUri: string,
) => {
  try {
    const deployment = await getDeployment(token, {
      name: ZTPFW_DEPLOYMENT_NAME,
      namespace: ZTPFW_NAMESPACE,
    });
    const env = deployment.spec?.template?.spec?.containers?.[0].env;
    if (!env) {
      logger.error(
        'Can not find either env variables or volumes in the ZTPFW UI Deployment resource',
      );
      return;
    }
    const frontendEnv = env.find((e) => e.name === 'FRONTEND_URL');
    if (frontendEnv) {
      frontendEnv.value = `https://${ztpfwDomain}`;
    } else {
      logger.warn('Can not find FRONTEND_URL env variable in the ZTPFW UI Deployment resource');
    }
    const redirectEnv = env.find((e) => e.name === 'OAUTH2_REDIRECT_URL');
    if (redirectEnv) {
      redirectEnv.value = newOauthRedirectUri;
    } else {
      logger.warn(
        'Can not find OAUTH2_REDIRECT_URL env variable in the ZTPFW UI Deployment resource',
      );
    }

    const patchesDeployment: PatchType[] = [
      {
        op: 'replace',
        path: '/spec/template/spec/containers',
        value: deployment.spec?.template?.spec?.containers,
      },
    ];
    await patchDeployment(
      token,
      {
        name: ZTPFW_DEPLOYMENT_NAME,
        namespace: ZTPFW_NAMESPACE,
      },
      patchesDeployment,
    );
    logger.debug('ZTPFW UI Deployment patched');
  } catch (e) {
    logger.error('Failed to patch ZTPFW UI Deployment: ', e);
  }
};

const updateZtpfwUI = async (token: string, ztpfwDomain: string) => {
  // route
  try {
    const route = await getRoute(token, { name: ZTPFW_ROUTE_NAME, namespace: ZTPFW_NAMESPACE });

    // Make a copy to be able to make livenessProbe requests from browser (new route hots CORS issue)
    await backupRoute(token, route);

    await updateSingleRoute(token, ztpfwDomain, route);
    logger.debug('ZTPFW UI Route patched');
  } catch (e) {
    logger.error('Failed to patch ZTPFW UI Route: ', e);
  }

  // oauth-client
  const newOauthRedirectUri = await updateOauthRedirectUri(token, ztpfwDomain);

  // Deployment
  await updateZtpfwDeployment(token, ztpfwDomain, newOauthRedirectUri);
};

const isDomainChanged = (
  res: Response,
  apiDomain: string,
  newDomain: string,
  oldDomain?: string,
) => {
  if (oldDomain === newDomain) {
    logger.info(
      'Domain stays unchanged (based on the Ingress config), skipping persistence of it.',
    );
    res.writeHead(200).end(); // All good
    return false;
  }
  logger.debug(
    `About to change domain from "${oldDomain}" to "${newDomain}" (api: "${apiDomain}")`,
  );

  return true;
};

/**
 * Will perform cluster domain change.
 * Intentionally executed on the backend to decrease risks of network issues during the complex flow.
 *
 * In a nutshell:
 * - skip if no change is actually needed
 *
 * - the apiserver/cluster resource
 *   - create Secret with new TLS certificate
 *   - prepare PATCH request
 *
 * - prepare PATCH request for the ingress/cluster resource
 *   - update spec.componentRoutes of a few selected routes
 *     - create Secret with new TLS certificate
 *     - update relevant item of the spec.componentRoutes
 *   - update spec.domain
 *
 * - call HTTP PATCH on
 *   - apiserver/cluster
 *   - ingress/cluster
 *
 * - update ZTPFW UI
 *   - the route resource for the new domain
 *   - OAuthClient for login callback
 *   - Deployment for env variables
 *   - side-effect: our pod is terminated (consequence of the Deployment resource change)
 *
 */
const changeDomainImpl = async (
  res: Response,
  token: string,
  input: ChangeDomainInputType,
): Promise<void> => {
  const clusterDomain = validateInput(DNS_NAME_REGEX, input.clusterDomain);
  logger.debug('ChangeDomain endpoint called, domain:', clusterDomain);

  if (!clusterDomain) {
    res.writeHead(422).end();
    return;
  }

  const ingress = await getIngressConfig(token);

  const oldIngressDomain = getIngressDomain(getClusterDomainFromComponentRoutes(ingress) || '');
  const apiDomain = getApiDomain(clusterDomain);
  const ingressDomain = getIngressDomain(clusterDomain);

  if (!isDomainChanged(res, apiDomain, ingressDomain, oldIngressDomain)) {
    return;
  }

  // Prepare patch to change API certificate (apiserver/cluster resource) - will be executed at the end of the flow
  const apiCertSecretName = await createTlsSecret(
    res,
    token,
    apiDomain,
    'api-secret-',
    input.customCerts,
  );
  if (!apiCertSecretName) {
    return;
  }
  const namedCertificates = [
    // This is potentially buggy in case the ApiServer cluster has already namedCertificates present
    { names: [apiDomain], servingCertificate: { name: apiCertSecretName } },
  ];
  const apiServerPatches: { spec: ApiServerSpec } = {
    // It will result in a MERGE patch
    spec: {
      servingCerts: {
        namedCertificates,
      },
    },
  };

  // Prepare ingress /cluster resource patch - will be executed at the end of the flow
  const consoleDomain = getConsoleDomain(clusterDomain);
  const oauthDomain = getOauthDomain(clusterDomain);
  const ztpfwDomain = getZtpfwDomain(clusterDomain);

  const componentRoutes = ingress?.spec?.componentRoutes || [];
  const consoleTlsSecretName = await updateIngressComponentRoutes(
    res,
    token,
    input.customCerts,
    componentRoutes,
    'console',
    consoleDomain,
    'console-secret-',
    'openshift-console', // namespace
  );
  const oauthTlsSecretName = await updateIngressComponentRoutes(
    res,
    token,
    input.customCerts,
    componentRoutes,
    'oauth-openshift',
    oauthDomain,
    'oauth-secret-',
    OAUTH_NAMESPACE,
  );
  const ztpfwUiTlsSecretName = await updateIngressComponentRoutes(
    res,
    token,
    input.customCerts,
    componentRoutes,
    ZTPFW_UI_ROUTE_PREFIX,
    ztpfwDomain,
    'ztpfw-secret-',
    ZTPFW_NAMESPACE,
  );
  if (!(consoleTlsSecretName && oauthTlsSecretName && ztpfwUiTlsSecretName)) {
    // TODO: Anything else??
    logger.info('Update of an ingress component route failed, exiting.');
    return;
  }

  const ingressPatches: PatchType[] = [
    // { Do not change domain but add a new one
    //   op: ingress?.spec?.domain ? 'replace' : 'add',
    //   path: '/spec/domain',
    //   value: ingressDomain,
    // },
    {
      op: ingress?.spec?.componentRoutes ? 'replace' : 'add',
      path: '/spec/componentRoutes',
      value: componentRoutes,
    },
  ];

  // Persist the changes (call PATCH)
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

  // This will terminate our pod
  await updateZtpfwUI(token, ztpfwDomain);

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
        const encoded = JSON.parse(data) as ChangeDomainInputType;
        await changeDomainImpl(res, token, encoded);
      } catch (e) {
        logger.error('Failed to parse input for changeDomain');
        res.writeHead(422).end();
      }
    });
}
