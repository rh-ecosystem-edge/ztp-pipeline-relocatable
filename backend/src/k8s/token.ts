import { Request } from 'express';
import { constants } from 'http2';
import { parseCookies } from './cookies';

const { HTTP2_HEADER_AUTHORIZATION } = constants;

export const K8S_ACCESS_TOKEN_COOKIE = 'k8s-access-token-cookie';

export function getToken(req: Request): string | undefined {
  let token = parseCookies(req)[K8S_ACCESS_TOKEN_COOKIE];
  if (!token) {
    const authorizationHeader = req.headers[HTTP2_HEADER_AUTHORIZATION];
    if (typeof authorizationHeader === 'string' && authorizationHeader.startsWith('Bearer ')) {
      token = authorizationHeader.slice(7);
    }
  }
  return token;
}
