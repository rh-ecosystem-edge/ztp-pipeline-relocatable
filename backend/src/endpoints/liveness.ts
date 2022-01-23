import { Request, Response } from "express";
import { readFileSync } from "fs";
import { constants } from "http2";
import { Agent } from "https";
import { FetchError } from "node-fetch";

import { fetchRetry } from "../k8s/fetch-retry";
import { respondInternalServerError, respondOK } from "../k8s/respond";
import { getOauthInfoPromise } from "../k8s/oauth";

const { HTTP2_HEADER_AUTHORIZATION } = constants;
const logger = console;
const agent = new Agent({ rejectUnauthorized: false });
let serviceAcccountToken: string;

export let isLive = true;

// The kubelet uses liveness probes to know when to restart a container.
export async function liveness(req: Request, res: Response): Promise<void> {
  if (!isLive) return respondInternalServerError(req, res);
  const oauthInfo = await getOauthInfoPromise();
  if (!oauthInfo.authorization_endpoint)
    return respondInternalServerError(req, res);
  return respondOK(req, res);
}

export function setDead(): void {
  if (isLive) {
    logger.warn("liveness set to false");
    isLive = false;
  }
}

export function getServiceAcccountToken(): string {
  if (serviceAcccountToken === undefined) {
    try {
      serviceAcccountToken = readFileSync(
        "/var/run/secrets/kubernetes.io/serviceaccount/token"
      ).toString();
    } catch (err) {
      serviceAcccountToken = process.env.TOKEN || "";
      if (!serviceAcccountToken) {
        logger.error("service account token not found");
        process.exit(1);
      }
    }
  }
  return serviceAcccountToken;
}

export async function apiServerPing(): Promise<void> {
  try {
    const response = await fetchRetry(process.env.CLUSTER_API_URL + "/apis", {
      headers: {
        [HTTP2_HEADER_AUTHORIZATION]: `Bearer ${serviceAcccountToken}`,
      },
      agent,
    });
    if (response.status !== 200) {
      setDead();
    }
    void response.blob();
  } catch (err) {
    if (err instanceof FetchError) {
      logger.error({ msg: "kube api server ping failed", error: err.message });
      if (err.errno === "ENOTFOUND" || err.code === "ENOTFOUND") {
        setDead();
      }
    } else if (err instanceof Error) {
      logger.error({ msg: "api server ping failed", error: err.message });
    } else {
      logger.error({ msg: "api server ping failed", err: err as unknown });
    }
  }
}

if (process.env.NODE_ENV === "production") {
  setInterval(apiServerPing, 30 * 1000).unref();
}
