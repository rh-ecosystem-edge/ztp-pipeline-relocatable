import { Request, Response } from 'express';

import { respondInternalServerError, respondOK } from '../k8s/respond';
import { isLive } from './liveness';
import { getOauthInfoPromise } from '../k8s/oauth';

// The kubelet uses readiness probes to know when a container is ready to start accepting traffic
export async function readiness(req: Request, res: Response): Promise<void> {
  if (!isLive) return respondInternalServerError(req, res);
  const oauthInfo = await getOauthInfoPromise();
  if (!oauthInfo.authorization_endpoint) return respondInternalServerError(req, res);
  return respondOK(req, res);
}
