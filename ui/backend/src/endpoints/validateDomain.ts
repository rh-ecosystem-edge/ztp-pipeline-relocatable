import { exec, ExecException } from 'child_process';
import { Request, Response } from 'express';
import {
  DNS_NAME_REGEX,
  getApiDomain,
  getIngressDomain,
  ValidateDomainAPIResult,
  ValidateDomainAPIInput,
} from '../frontend-shared';
import { validateInput } from './utils';

const logger = console;

const digDomain = (res: Response, domain: string, onSuccess: () => void) => {
  exec(
    `dig +short ${domain} | head -1`,
    (error: ExecException | null, stdout?: string, stderr?: string) => {
      if (error) {
        logger.error('dig error: ', error, stderr?.trim());
        res.writeHead(422).end();
        return;
      }

      if (stdout?.trim()) {
        onSuccess();
      } else {
        logger.info('Domain validation failed: ', domain);
        const response: ValidateDomainAPIResult = { result: false };
        res.json(response);
      }
    },
  );
};

function validateDomainImpl(res: Response, _domain?: string): void {
  const domain = validateInput(DNS_NAME_REGEX, _domain);
  logger.debug('Validate domain endpoint called, domain:', domain);

  if (!domain) {
    logger.error('validate domain: missing domain as input');
    res.writeHead(422).end();
    return;
  }

  digDomain(res, getApiDomain(domain), () => {
    digDomain(res, getIngressDomain(domain), () => {
      logger.debug('Domain validated successfully: ', domain);
      const response: ValidateDomainAPIResult = { result: true };
      res.json(response);
    });
  });
}

export function validateDomain(req: Request, res: Response): void {
  logger.debug('Validate domain called');

  // Do not register server middleware just for that
  const body: Buffer[] = [];
  req
    .on('data', (chunk: Buffer) => {
      body.push(chunk);
    })
    .on('end', () => {
      try {
        const data: string = Buffer.concat(body).toString();
        const encoded = JSON.parse(data) as ValidateDomainAPIInput;
        validateDomainImpl(res, encoded?.domain);
      } catch (e) {
        logger.error('Validate domain: Failed to parse input');
        res.writeHead(422);
      }
    });
}
