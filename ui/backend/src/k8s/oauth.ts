import { Request, Response } from 'express';
import { createHash } from 'crypto';
import { IncomingMessage } from 'http';
import { Agent, request } from 'https';
import { encode as stringifyQuery, parse as parseQueryString } from 'querystring';

// import { setDead } from '../endpoints/liveness';
import { getClusterApiUrl } from './utils';
import { deleteCookie } from './cookies';
import { jsonRequest } from './json-request';
import { getToken, K8S_ACCESS_TOKEN_COOKIE } from './token';
import { redirect, respondInternalServerError, unauthorized } from './respond';
import { OAUTH_ROUTE_PREFIX, ZTPFW_UI_ROUTE_PREFIX } from '../constants';

const logger = console;

// type OAuthInfo = { authorization_endpoint: string; token_endpoint: string };
// let oauthInfoPromise: Promise<OAuthInfo>;

export const getOauthInfo = () => {
  /* This does not work after domain change
  if (oauthInfoPromise === undefined) {
    oauthInfoPromise = jsonRequest<OAuthInfo>(
      `${getClusterApiUrl()}/.well-known/oauth-authorization-server`,
    ).catch((err: Error) => {
      logger.error({
        msg: 'oauth-authorization-server error',
        error: err.message,
      });
      setDead();
      return {
        authorization_endpoint: '',
        token_endpoint: '',
      };
    });
  }
  return oauthInfoPromise;
  */

  // We need to hardcode it
  const oauthServer = (process.env.FRONTEND_URL || 'missing-frontend-url').replace(
    ZTPFW_UI_ROUTE_PREFIX,
    OAUTH_ROUTE_PREFIX,
  );
  const oauth = {
    // https://oauth-openshift.apps.spoke0-cluster.alklabs.local/oauth/authorize
    authorization_endpoint: `${oauthServer}/oauth/authorize`,
    token_endpoint: `${oauthServer}/oauth/token`,
  };

  return oauth;
};

export const login = (_: Request, res: Response): void => {
  logger.log('Login requested');
  const oauthInfo = getOauthInfo();

  const queryString = stringifyQuery({
    response_type: `code`,
    client_id: process.env.OAUTH2_CLIENT_ID,
    redirect_uri: process.env.OAUTH2_REDIRECT_URL,
    scope: `user:full`,
    state: '',
  });
  const url = `${oauthInfo.authorization_endpoint}?${queryString}`;
  logger.log('Login redirect: ', url);

  return redirect(res, url);
};

export const loginCallback = async (req: Request, res: Response): Promise<void> => {
  const url = req.url;
  logger.debug('Login callback');

  if (url.includes('?')) {
    const oauthInfo = getOauthInfo();
    const queryString = url.substr(url.indexOf('?') + 1);
    const query = parseQueryString(queryString);
    const code = query.code as string;
    // const state = query.state
    const requestQuery: Record<string, string> = {
      grant_type: `authorization_code`,
      code: code,
      redirect_uri: process.env.OAUTH2_REDIRECT_URL || '',
      client_id: process.env.OAUTH2_CLIENT_ID || '',
      client_secret: process.env.OAUTH2_CLIENT_SECRET || '',
    };
    const requestQueryString = stringifyQuery(requestQuery);
    const body = await jsonRequest<{ access_token: string }>(
      oauthInfo.token_endpoint + '?' + requestQueryString,
    );
    if (body.access_token) {
      let attributes: string;
      // if (process.env.NODE_ENV === 'production') {
      if (process.env.FRONTEND_URL?.startsWith('https://')) {
        attributes = 'Secure; Path=/';
      } else {
        logger.log('Setting HttpOnly cookie.');
        attributes = 'HttpOnly; Path=/';
      }

      const headers = {
        'Set-Cookie': `${K8S_ACCESS_TOKEN_COOKIE}=${body.access_token}; ${attributes}`,
        location: process.env.FRONTEND_URL,
      };
      res.writeHead(302, headers).end();
      return;
    } else {
      return respondInternalServerError(req, res);
    }
  } else {
    return respondInternalServerError(req, res);
  }
};

export function logout(req: Request, res: Response): void {
  logger.debug('Logout called');
  const token = getToken(req);
  if (!token) return unauthorized(req, res);

  let tokenName = token;
  const sha256Prefix = 'sha256~';
  if (tokenName.startsWith(sha256Prefix)) {
    tokenName = `sha256~${createHash('sha256')
      .update(token.substring(sha256Prefix.length))
      .digest('base64')
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')}`;
  }

  const clientRequest = request(
    // /apis/oauth.openshift.io/v1/oauthaccesstokens/sha256~e49cNiBYVhrRff3jpdZY2o1U2mjeEGQDRjvSKVREvNs
    `${getClusterApiUrl()}/apis/oauth.openshift.io/v1/oauthaccesstokens/${tokenName}?gracePeriodSeconds=0`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
      agent: new Agent({ rejectUnauthorized: false }),
    },
    (response: IncomingMessage) => {
      logger.debug('OAuth access token deleted');
      deleteCookie(res, K8S_ACCESS_TOKEN_COOKIE);
      res.writeHead(response.statusCode || 500).end();
    },
  );
  clientRequest.on('error', () => {
    logger.warn('Failed to delete OAuth access token');
    respondInternalServerError(req, res);
  });
  clientRequest.end();
}
