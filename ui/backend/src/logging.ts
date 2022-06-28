import { IncomingMessage } from 'http';
import { RequestOptions } from 'https';
import { RequestInfo, RequestInit, Response } from 'node-fetch';

const isAPILoggingEnabled = (): boolean => process.env.API_LOGGING_ENABLED === 'true';

export const logRequest = (url: RequestInfo, init?: RequestInit) => {
  if (isAPILoggingEnabled()) {
    if (!url?.toString()?.endsWith('/apis')) {
      console.log('API Request:\n', url, '\ninit:\n', init);
    }
  }
};

export const logResponse = (response: Response, url?: RequestInfo) => {
  if (isAPILoggingEnabled()) {
    if (!url?.toString()?.endsWith('/apis')) {
      // skip logging livenessProbe
      console.log('API Response:\n', response);
    }
  }
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const logRequestError = (err: any) => {
  if (isAPILoggingEnabled()) {
    console.log('Request error: \n', err);
  }
};

export const logRequestProxy = (options: RequestOptions) => {
  if (isAPILoggingEnabled()) {
    console.log('Proxied API Request:\n', options);
  }
};

export const logResponseProxy = (response: IncomingMessage) => {
  if (isAPILoggingEnabled()) {
    console.log(
      'Proxied API Response (skipping data):\nstatusCode: ',
      response['statusCode'],
      '\nstatusMessage: ',
      response['statusMessage'],
      '\noriginal request:\n',
      // eslint-disable-next-line @typescript-eslint/ban-ts-comment
      // @ts-ignore
      response['_httpMessage'],
      '\nrawHeaders: ',
      response['rawHeaders'],
      '\n',
    );
  }
};

export const logRequestResponse = (
  method: string,
  url: RequestInfo,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  request: any,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  response?: any,
) => {
  if (isAPILoggingEnabled()) {
    try {
      console.log(
        `----- ${method} API request to: ${url.toString() || ''}: \n`,
        request,
        '\nresponse:\n',
        response,
        '\n----------',
      );
    } catch (err) {
      console.error(`Error during logging ${method || ''} API request to: ${url.toString() || ''}`);
    }
  }
};
