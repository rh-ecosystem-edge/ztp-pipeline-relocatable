import { exec, ExecException } from 'child_process';
import { Request, Response } from 'express';
import { rmdirSync } from 'fs';

import { validateInput } from './utils';

const logger = console;

// Keep in sync with the frontend
const DNS_NAME_REGEX =
  /^(((?!\\-))(xn\\-\\-)?[a-z0-9\-_]{0,61}[a-z0-9]{1,1}\.)*(xn\\-\\-)?([a-z0-9\\-]{1,61}|[a-z0-9\\-]{1,30})\.[a-z]{2,}$/;

function generateCertificateImpl(res: Response, _domain?: string): void {
  const domain = validateInput(DNS_NAME_REGEX, _domain);
  logger.debug('GenerateCertificate endpoint called, domain:', domain);

  if (!domain) {
    res.writeHead(422).end();
    return;
  }

  exec(
    // We should have enough space for that by default (devicemapper's basesize config param is 10GB by default)
    'mktemp -d /tmp/generateCertificate-XXXXXX',
    (error: ExecException | null, _tmpdir?: string, stderr?: string) => {
      if (error) {
        logger.error('mktemp failed', error, stderr?.trim());
        res.writeHead(422).end();
        return;
      }
      const tmpdir = _tmpdir?.trim() || '/tmp';
      const keyFile = `${tmpdir}/api-key.pem`;
      const certFile = `${tmpdir}/api-cert.pem`;
      const delimiter = '-----generateCertificateDelimiter-----';
      exec(
        `/usr/bin/openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout ${keyFile} -out ${certFile} -subj "/CN=${domain}" -addext "subjectAltName = DNS:${domain}" && cat ${keyFile} && echo ${delimiter} && cat ${certFile}`,
        (error: ExecException | null, stdout = '', stderr?: string) => {
          if (error) {
            logger.error('openssl error: ', error, stderr?.trim());
            rmdirSync(tmpdir, { recursive: true, maxRetries: 5 });
            res.writeHead(422).end();
            return;
          }

          const tlsKey = stdout.substr(0, stdout.indexOf(delimiter));
          const tlsCrt = stdout.substr(stdout.indexOf(delimiter) + delimiter.length);
          
          logger.debug('Remove me: received stdout: ', stdout);
          logger.debug('tlsKey: ', tlsKey);
          logger.debug('tlsCrt: ', tlsCrt);

          rmdirSync(tmpdir, { recursive: true, maxRetries: 5 });
          res.json({
            'tls.crt': atob(tlsCrt),
            'tls.key': btoa(tlsKey),
          });
        },
      );
    },
  );
}

export function generateCertificate(req: Request, res: Response): void {
  logger.debug('GenerateCertificate called');

  // Do not register server middleware just for that
  const body: Buffer[] = [];
  req
    .on('data', (chunk: Buffer) => {
      body.push(chunk);
    })
    .on('end', () => {
      try {
        const data: string = Buffer.concat(body).toString();
        const encoded = JSON.parse(data) as { domain?: string };
        generateCertificateImpl(res, encoded?.domain);
      } catch (e) {
        logger.error('Failed to parse input for generateCertificate');
        res.writeHead(422);
      }
    });
}
