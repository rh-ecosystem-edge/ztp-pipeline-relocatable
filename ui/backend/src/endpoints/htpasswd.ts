import { exec, ExecException } from 'child_process';
import { Request, Response } from 'express';
import { PWD_REGEX, USERNAME_REGEX } from '../frontend-shared';
import { validateInput } from './utils';

const logger = console;

function htpasswdImpl(res: Response, _username?: string, _password?: string): void {
  const username = validateInput(USERNAME_REGEX, _username);
  logger.debug('Htpasswd endpoint called, username:', username);
  const password = validateInput(PWD_REGEX, _password);

  if (!username || !password) {
    logger.error('htpasswd: missing either username or password');
    res.writeHead(422).end();
    return;
  }

  exec(
    `/usr/bin/htpasswd -nBb "${username}" "${password}"`,
    (error: ExecException | null, stdout?: string, stderr?: string) => {
      if (error) {
        logger.error('htpasswd error: ', error, stderr?.trim());
        res.writeHead(422).end();
        return;
      }
      res.json({ htpasswdData: stdout?.trim() });
    },
  );
}

export function htpasswd(req: Request, res: Response): void {
  logger.debug('Htpasswd called');

  // Do not register server middleware just for that
  const body: Buffer[] = [];
  req
    .on('data', (chunk: Buffer) => {
      body.push(chunk);
    })
    .on('end', () => {
      try {
        const data: string = Buffer.concat(body).toString();
        const encoded = JSON.parse(data) as { username?: string; password?: string };
        htpasswdImpl(res, encoded?.username, encoded?.password);
      } catch (e) {
        logger.error('htpasswd: Failed to parse input');
        res.writeHead(422);
      }
    });
}
