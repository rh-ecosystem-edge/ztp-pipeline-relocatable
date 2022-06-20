import { constants } from 'http2';
import { Agent } from 'https';
import { HeadersInit } from 'node-fetch';
import { logRequestResponse } from '../logging';
import { fetchRetry } from './fetch-retry';

const { HTTP2_HEADER_CONTENT_TYPE, HTTP2_HEADER_AUTHORIZATION, HTTP2_HEADER_ACCEPT } = constants;

const agent = new Agent({ rejectUnauthorized: false });

export function jsonRequest<T>(url: string, token?: string): Promise<T> {
  const headers: HeadersInit = { [HTTP2_HEADER_ACCEPT]: 'application/json' };
  if (token) headers[HTTP2_HEADER_AUTHORIZATION] = `Bearer ${token}`;
  const request = { headers, agent, compress: true };
  return fetchRetry(url, request).then(async (response) => {
    const result = (await response.json()) as unknown as Promise<T>;
    logRequestResponse('GET', url, request, result);
    return result;
  });
}

export interface PostResponse<T> {
  statusCode: number;
  body?: T;
}

export function jsonPost<T = unknown>(
  url: string,
  body: unknown,
  token?: string,
): Promise<PostResponse<T>> {
  const headers: HeadersInit = {
    [HTTP2_HEADER_ACCEPT]: 'application/json',
    [HTTP2_HEADER_CONTENT_TYPE]: 'application/json',
  };
  if (token) headers[HTTP2_HEADER_AUTHORIZATION] = `Bearer ${token}`;

  const request = {
    method: 'POST',
    headers,
    agent,
    body: JSON.stringify(body),
    compress: true,
  };

  return fetchRetry(url, request).then(async (response) => {
    const result = {
      statusCode: response.status,
      body: (await response.json()) as unknown as T,
    };
    logRequestResponse('POST', url, request, result);
    return result;
  });
}

export function jsonPatch<T = unknown>(
  url: string,
  patches: unknown,
  token: string,
): Promise<PostResponse<T>> {
  const headers: HeadersInit = {};
  headers[HTTP2_HEADER_AUTHORIZATION] = `Bearer ${token}`;

  if (Array.isArray(patches)) {
    headers['Content-Type'] = 'application/json-patch+json';
  } else {
    headers['Content-Type'] = 'application/merge-patch+json';
  }

  const request = {
    method: 'PATCH',
    headers,
    agent,
    body: JSON.stringify(patches),
    compress: true,
  };

  return fetchRetry(url, request).then(async (response) => {
    const result = {
      statusCode: response.status,
      body: (await response.json()) as unknown as T,
    };

    logRequestResponse('PATCH', url, request, result);
    return result;
  });
}

export function jsonDelete<T = unknown>(url: string, token: string): Promise<PostResponse<T>> {
  const headers: HeadersInit = {};
  headers[HTTP2_HEADER_AUTHORIZATION] = `Bearer ${token}`;

  const request = {
    method: 'DELETE',
    headers,
    agent,
    compress: true,
  };
  return fetchRetry(url, request).then(async (response) => {
    const result = {
      statusCode: response.status,
      body: (await response.json()) as unknown as T,
    };
    logRequestResponse('DELETE', url, request, result);
    return result;
  });
}
