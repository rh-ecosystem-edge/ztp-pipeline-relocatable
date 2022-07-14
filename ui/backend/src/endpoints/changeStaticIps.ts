import { cloneDeep } from 'lodash';
import { Request, Response } from 'express';

import {
  ChangeStaticIpsInputType,
  PatchType,
  NodeNetworkConfigurationPolicy,
  NNCPInterface,
  HostType,
  NNRouteConfig,
} from '../frontend-shared';
import { getToken, unauthorized } from '../k8s';
import {
  createNodeNetworkConfigurationPolicy,
  patchNodeNetworkConfigurationPolicy,
} from '../resources/nodenetworkconfigurationpolicy';
import { NNCP_TEMPLATE } from '../resources/resourceTemplates';
import { patchApiServerConfig } from '../resources/apiserver';

const logger = console;

const validateHost = (host: HostType): boolean =>
  !!host.nodeName &&
  !!host.dns?.length &&
  !!host.interfaces?.length &&
  host.interfaces?.every(
    (i) =>
      i.name && i.ipv4?.address?.gateway && i.ipv4?.address?.ip && i.ipv4?.address?.prefixLength,
  );

const changeStaticIpsImpl = async (
  res: Response,
  token: string,
  input: ChangeStaticIpsInputType,
): Promise<void> => {
  logger.debug('ChangeStaticIps endpoint called, input:', input);

  const hosts = input.hosts;

  if (!hosts?.length) {
    res.writeHead(422).end();
    return;
  }

  // Store the data
  // Optimization: instead of sequential processing wait on all promises at once (not implemented atm due to debugging)
  for (let index = 0; index < hosts.length; index++) {
    const host = hosts[index];

    if (!validateHost(host)) {
      logger.error('ChangeStaticIps incorrect input, host: ', host);
      res.writeHead(422, `Incorrect host ${host.nodeName}`).end();
      break;
    }

    if (host.nncpName) {
      // assumption: the spec.nodeSelector is already properly set (otherwise host.nncpName would not be provided) - so we can PATCH right away

      const patches: PatchType[] = [];

      patches.push({
        // TODO: remove following, it is used for debugging only:
        op: 'replace',
        path: '/spec/nodeSelector',
        value: {
          'ui-debug-not-mataching-key': 'not-matching-label',
        },
      });

      const dns = host.dns?.length
        ? {
            config: {
              server: host.dns,
            },
          }
        : undefined;

      const routes = {
        config: host.interfaces
          .map((i): NNRouteConfig | undefined => {
            const gateway = i.ipv4.address?.gateway || '';

            return {
              destination: '0.0.0.0/0', // TODO: Can we use this as default??
              metric: 1000,
              'next-hop-address': gateway,
              'next-hop-interface': i.name,
            };
          })
          .filter(Boolean) as NNRouteConfig[],
      };

      const desiredState: NodeNetworkConfigurationPolicy['spec']['desiredState'] = {
        interfaces: (host.interfaces || [])
          ?.map((i): NNCPInterface | undefined => {
            const ip = i.ipv4.address?.ip;
            const prefixLength = i.ipv4.address?.prefixLength;

            if (!ip || !prefixLength) {
              return undefined;
            }

            return {
              name: i.name,
              state: 'up',
              ipv4: {
                address: [
                  {
                    ip,
                    'prefix-length': prefixLength,
                  },
                ],
                enabled: true,
              },
            };
          })
          .filter(Boolean) as NNCPInterface[],
        'dns-resolver': dns,
        routes,
      };

      patches.push({
        op: 'replace', // let's risk here, to be safe we should query the NNCP first and then decide about replace vs. add
        path: '/spec/desiredState',
        value: desiredState,
      });

      try {
        logger.debug(`-- Patching NNCP ${host.nncpName}: `, patches);
        await patchNodeNetworkConfigurationPolicy(token, { name: host.nncpName }, patches);
      } catch (e) {
        logger.error(
          `Failed to patch NodeNetworkConfigurationPolicy "${host.nncpName}": `,
          patches,
          e,
        );
        res
          .writeHead(500, `Failed to patch NodeNetworkConfigurationPolicy "${host.nncpName}"`)
          .end();
        return;
      }
    } else {
      // create one from a template
      const nncp = cloneDeep(NNCP_TEMPLATE);
      const namePrefix = `${host.nodeName}-`;
      nncp.metadata.generateName = namePrefix;

      // TODO: other changes

      try {
        const response = await createNodeNetworkConfigurationPolicy(token, nncp);

        if (response.statusCode === 201) {
          logger.info('Created a NNCP resource: ', response.body?.metadata?.name);
        } else {
          logger.error(
            `Can not create ${namePrefix} NodeNetworkConfigurationPolicy resource. Response: `,
            response,
          );
          res
            .writeHead(
              response.statusCode,
              `Can not create ${namePrefix} NodeNetworkConfigurationPolicy resource.`,
            )
            .end();
        }
      } catch (e) {
        logger.error(
          `Can not create ${namePrefix} NodeNetworkConfigurationPolicy resource.  Internal error: `,
          e,
        );
        res
          .writeHead(
            500,
            `Can not create ${namePrefix} NodeNetworkConfigurationPolicy resource.  Internal error.`,
          )
          .end();
      }
    }
  }

  res.writeHead(200).end(); // All good
};

export function changeStaticIps(req: Request, res: Response): void {
  logger.debug('changeStaticIps endpoint called');
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
        const encoded = JSON.parse(data) as ChangeStaticIpsInputType;
        await changeStaticIpsImpl(res, token, encoded);
      } catch (e) {
        logger.error('Failed to parse input for changeStaticIps');
        res.writeHead(422).end();
      }
    });
}
