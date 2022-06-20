import { Request, Response } from 'express';
import { constants, OutgoingHttpHeaders } from 'http2';
import { request, RequestOptions } from 'https';
import { pipeline } from 'stream';
import { URL } from 'url';

import { notFound, unauthorized, getToken, respondInternalServerError } from '../k8s';
import { getClusterApiUrl } from '../k8s/utils';
import { logRequestProxy, logResponseProxy } from '../logging';

const logger = console;

const proxyHeaders = [
  constants.HTTP2_HEADER_ACCEPT,
  constants.HTTP2_HEADER_ACCEPT_ENCODING,
  constants.HTTP2_HEADER_CONTENT_ENCODING,
  constants.HTTP2_HEADER_CONTENT_LENGTH,
  constants.HTTP2_HEADER_CONTENT_TYPE,
];
const proxyResponseHeaders = [
  constants.HTTP2_HEADER_CACHE_CONTROL,
  constants.HTTP2_HEADER_CONTENT_TYPE,
  constants.HTTP2_HEADER_CONTENT_LENGTH,
  constants.HTTP2_HEADER_CONTENT_ENCODING,
  constants.HTTP2_HEADER_ETAG,
];

export function proxy(req: Request, res: Response): void {
  const token = getToken(req);
  logger.debug('Proxy endpoint: ', req.url);
  if (!token) return unauthorized(req, res);

  if (!getClusterApiUrl()) {
    return respondInternalServerError(req, res);
  }
  const url = req.url;

  const headers: OutgoingHttpHeaders = { authorization: `Bearer ${token}` };
  for (const header of proxyHeaders) {
    if (req.headers[header]) headers[header] = req.headers[header];
  }

  const clusterUrl = new URL(getClusterApiUrl());
  const options: RequestOptions = {
    protocol: clusterUrl.protocol,
    hostname: clusterUrl.hostname,
    port: clusterUrl.port,
    path: url,
    method: req.method,
    headers,
    rejectUnauthorized: false,
  };
  logRequestProxy(options);
  pipeline(
    req,
    request(options, (response) => {
      logResponseProxy(response);
      if (!response) return notFound(req, res);
      const responseHeaders: OutgoingHttpHeaders = {};
      for (const header of proxyResponseHeaders) {
        if (response.headers[header]) responseHeaders[header] = response.headers[header];
      }
      res.writeHead(response.statusCode ?? 500, responseHeaders);
      pipeline(response, res as unknown as NodeJS.WritableStream, function (this: void, ...args) {
        logger.error(...args);
      });
    }),
    (err) => {
      if (err) logger.error(err);
    },
  );
}
