import { cloneDeep } from 'lodash';
import { Response } from 'express';
import { rmdirSync } from 'fs';
import { exec } from 'promisify-child-process';
import { TLS_SECRET } from '../resources/resourceTemplates';
import { createSecret } from '../resources/secret';
import { Secret, TlsCertificate } from '../frontend-shared';

const logger = console;

export const generateCertificate = async (
  res: Response,
  domain: string,
): Promise<TlsCertificate | undefined> => {
  logger.debug('generateCertificate called for domain:', domain);

  try {
    const { stdout: _stdout } = await exec('mktemp -d /tmp/generateCertificate-XXXXXX');
    const stdout = _stdout?.toString();

    const tmpdir = stdout?.trim() || '/tmp';
    const keyFile = `${tmpdir}/api-key.pem`;
    const certFile = `${tmpdir}/api-cert.pem`;
    const delimiter = '-----generateCertificateDelimiter-----';

    try {
      const { stdout: _stdout } = await exec(
        `/usr/bin/openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout ${keyFile} -out ${certFile} -subj "/CN=${domain}" -addext "subjectAltName = DNS:${domain}" && cat ${keyFile} && echo ${delimiter} && cat ${certFile}`,
      );
      rmdirSync(tmpdir, { recursive: true, maxRetries: 5 });

      const stdout = _stdout?.toString();
      const tlsKey = stdout?.substr(0, stdout.indexOf(delimiter));
      const tlsCrt = stdout?.substr(stdout.indexOf(delimiter) + delimiter.length);

      if (!tlsKey || !tlsCrt) {
        logger.error('Error getting certificate via openssl, stdout: ', stdout);
        res.writeHead(500, 'Failed to generate certificate (openssl), empty key or cert').end();
        return;
      }

      return {
        'tls.crt': Buffer.from(tlsCrt).toString('base64'),
        'tls.key': Buffer.from(tlsKey).toString('base64'),
      };
    } catch (e) {
      logger.error('openssl error: ', e);
      rmdirSync(tmpdir, { recursive: true, maxRetries: 5 });
      res.writeHead(500, 'Failed to generate certificate (openssl)').end();
      return;
    }
  } catch (e) {
    logger.error('mktemp failed: ', e);
    res.writeHead(500, 'Failed to mktemp.').end();
    return;
  }
};

export const createCertSecret = async (
  res: Response,
  token: string,
  namePrefix: string,
  certificate: TlsCertificate,
): Promise<Secret | undefined> => {
  try {
    const object = cloneDeep(TLS_SECRET);
    object.metadata.generateName = namePrefix;
    object.data = certificate;

    // TODO: what about clean-up?
    const response = await createSecret(token, object);
    if (response.statusCode === 201) {
      // HTTP Created
      return response.body;
    }

    res
      .writeHead(
        response.statusCode,
        `Can not create ${namePrefix} TLS secret in the ${
          TLS_SECRET.metadata.namespace || ''
        } namespace.`,
      )
      .end();
  } catch (e) {
    res
      .writeHead(
        500,
        `Can not create ${namePrefix} TLS secret in the ${
          TLS_SECRET.metadata.namespace || ''
        } namespace. Internal error.`,
      )
      .end();
  }

  return undefined;
};
