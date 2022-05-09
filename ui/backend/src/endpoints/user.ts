import { Request, Response } from 'express';
import { getToken, jsonPost, respondInternalServerError, unauthorized } from '../k8s';
import { getServiceAcccountToken } from './liveness';

const logger = console;

interface TokenReview {
  spec: {
    token: string;
  };
  status: {
    authenticated: boolean;
    error: string;
    user: {
      username: string;
    };
  };
}

export async function user(req: Request, res: Response): Promise<void> {
  logger.debug('User endpoint called');
  const token = getToken(req);
  if (!token) return unauthorized(req, res);

  const serviceAccountToken = getServiceAcccountToken();

  try {
    const response = await jsonPost<TokenReview>(
      `${
        process.env.CLUSTER_API_URL || 'missing-cluster-api-url'
      }/apis/authentication.k8s.io/v1/tokenreviews`,
      {
        apiVersion: 'authentication.k8s.io/v1',
        kind: 'TokenReview',
        spec: {
          token,
        },
      },
      serviceAccountToken,
    );
    const name =
      response.body &&
      response.body.status &&
      response.body.status.user &&
      response.body.status.user.username
        ? response.body.status.user.username
        : '';
    if (!name) {
      logger.info('The username for a token was not received, response: ', response);
    }    
    const responsePayload = {
      statusCode: response.statusCode,
      body: { username: name },
    };
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify(responsePayload));
  } catch (err) {
    logger.error(err);
    respondInternalServerError(req, res);
  }
}
