import { Request, Response } from 'express';
import { createHash } from 'crypto';
import got from 'got';
import { encode as stringifyQuery, parse as parseQueryString } from 'querystring';

import { getClusterApiUrl } from './utils';
import { deleteCookie } from './cookies';
import { jsonRequest } from './json-request';
import { getToken, K8S_ACCESS_TOKEN_COOKIE } from './token';
import { redirect, respondInternalServerError, unauthorized } from './respond';
import { setDead } from '../endpoints';
import { OAUTH_ROUTE_PREFIX, ZTPFW_UI_ROUTE_PREFIX } from '../frontend-shared';

const logger = console;

type OAuthInfo = { authorization_endpoint: string; token_endpoint: string };

export const getOauthInfoPromise = async () => {
  if (process.env.FRONTEND_URL?.startsWith('https://localhost')) {
    // dev environment
    // In production, this does not work after domain change
    const oauthInfo = await jsonRequest<OAuthInfo>(
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
    return {
      authorization_endpoint: oauthInfo.authorization_endpoint,
      token_endpoint: oauthInfo.token_endpoint,
    };
  }

  // We need to hardcode it in production
  const oauthServer = (process.env.FRONTEND_URL || 'missing-frontend-url').replace(
    ZTPFW_UI_ROUTE_PREFIX,
    OAUTH_ROUTE_PREFIX,
  );
  const oauth = {
    // https://oauth-openshift.apps.edgecluster0-cluster.alklabs.local/oauth/authorize
    authorization_endpoint: `${oauthServer}/oauth/authorize`,
    token_endpoint: `${oauthServer}/oauth/token`,
  };

  return oauth;
};

export const login = async (req: Request, res: Response): Promise<void> => {
  logger.log('Login requested');
  const oauthInfo = await getOauthInfoPromise();

  const state = req.url.split('?state=')[1] || '';

  const queryString = stringifyQuery({
    response_type: `code`,
    client_id: process.env.OAUTH2_CLIENT_ID,
    redirect_uri: process.env.OAUTH2_REDIRECT_URL,
    scope: `user:full`,
    state,
  });
  const url = `${oauthInfo.authorization_endpoint}?${queryString}`;

  // Following can not be used but would solve the logout issue for kubeadmin
  // deleteCookie(res, {cookie: 'ssn', domain: oauthInfo.authorization_endpoint})

  return redirect(res, url);
};

export const loginCallback = async (req: Request, res: Response): Promise<void> => {
  const url = req.url;
  logger.debug('Login callback');

  if (url.includes('?')) {
    const oauthInfo = await getOauthInfoPromise();
    const queryString = url.substr(url.indexOf('?') + 1);
    const query = parseQueryString(queryString);
    const code = query.code as string;
    const state = (query.state || '') as string;

    const requestQuery: Record<string, string> = {
      grant_type: `authorization_code`,
      code: code,
      redirect_uri: process.env.OAUTH2_REDIRECT_URL || '',
      client_id: process.env.OAUTH2_CLIENT_ID || '',
      client_secret: process.env.OAUTH2_CLIENT_SECRET || '',
    };
    const requestQueryString = stringifyQuery(requestQuery);
    console.log('Requesting access token via ', oauthInfo.token_endpoint);
    const body = await jsonRequest<{ access_token: string }>(
      oauthInfo.token_endpoint + '?' + requestQueryString,
    );
    if (body.access_token) {
      let attributes: string;
      if (process.env.FRONTEND_URL?.startsWith('https://')) {
        attributes = 'Secure; HttpOnly; Path=/';
      } else {
        logger.log('Setting HttpOnly cookie.');
        attributes = 'HttpOnly; Path=/';
      }

      const headers = {
        'Set-Cookie': `${K8S_ACCESS_TOKEN_COOKIE}=${body.access_token}; ${attributes}`,
        location: `${process.env.FRONTEND_URL || ''}${state}`,
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

export async function logout(req: Request, res: Response): Promise<void> {
  logger.debug('Logout called');

  const token = getToken(req);
  if (!token) return unauthorized(req, res);

  const gotOptions = {
    headers: { Authorization: `Bearer ${token}` },
    https: { rejectUnauthorized: false },
  };

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

  try {
    const url = `${getClusterApiUrl()}/apis/oauth.openshift.io/v1/oauthaccesstokens/${tokenName}?gracePeriodSeconds=0`;
    await got.delete(url, gotOptions);
  } catch (err) {
    logger.error(err);
  }

  // try {
  //   const url = `${getClusterApiUrl()}/apis/oauth.openshift.io/v1/useroauthaccesstokens/${tokenName}?gracePeriodSeconds=0`;
  //   await got.delete(url, gotOptions);
  // } catch (err) {
  //   logger.error(err);
  // }

  const host = req.headers.host;

  deleteCookie(res, { cookie: K8S_ACCESS_TOKEN_COOKIE });
  deleteCookie(res, { cookie: 'connect.sid' });
  deleteCookie(res, { cookie: '_oauth_proxy', domain: `.${host || ''}` });
  res.writeHead(200).end();
}
