import { Request, Response } from 'express';
import { getOauthInfoPromise } from '../k8s/oauth';

export async function configure(_: Request, res: Response): Promise<void> {
  const oauthInfo = await getOauthInfoPromise();
  const responsePayload = {
    token_endpoint: oauthInfo.token_endpoint,
  };
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify(responsePayload));
}
