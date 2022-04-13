import {
  getResourceApiPath,
  getResourceName,
  getResourceNameApiPath,
  IResource,
  ResourceList,
  Status,
  StatusKind,
} from '../backend-shared';

export interface IRequestResult<ResultType = unknown> {
  promise: Promise<ResultType>;
  abort: () => void;
}

export function resultsSettled<T>(
  results: IRequestResult<T>[],
): IRequestResult<PromiseSettledResult<T>[]> {
  return {
    promise: Promise.allSettled(results.map((result) => result.promise)),
    abort: () => results.forEach((result) => result.abort()),
  };
}

export function getCookie(name: string) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) {
    const cookie = parts.pop();
    if (cookie) return cookie.split(';').shift();
  }
}

export enum ResourceErrorCode {
  BadRequest = 400,
  Unauthorized = 401,
  Forbidden = 403,
  NotFound = 404,
  Timeout = 408,
  Conflict = 409,
  UnprocessableEntity = 422,
  TooManyRequests = 429,
  InternalServerError = 500,
  NotImplemented = 501,
  BadGateway = 502,
  ServiceUnavailable = 503,
  GatewayTimeout = 504,
  NetworkError = 700,
  RequestAborted = 800,
  ConnectionReset = 900,
  Unknown = 999,
}
const ResourceErrorCodes = Object.keys(ResourceErrorCode).map((k: string) =>
  Number(ResourceErrorCode[k as unknown as number]),
);

export class ResourceError extends Error {
  constructor(message: string, public code: ResourceErrorCode, public reason?: string) {
    super(message);
    Object.setPrototypeOf(this, ResourceError.prototype);
    this.name = 'ResourceError';
    this.code = code;
    this.reason = reason;
  }
}

export function getBackendUrl() {
  return process.env.REACT_APP_BACKEND_PATH || ''; //process.env.BACKEND_URL;
}

export function createResource<Resource extends IResource, ResultType = Resource>(
  resource: Resource,
): IRequestResult<ResultType> {
  const url = getBackendUrl() + getResourceApiPath(resource);
  return postRequest<Resource, ResultType>(url, resource);
}

export function replaceResource<Resource extends IResource, ResultType = Resource>(
  resource: Resource,
): IRequestResult<ResultType> {
  const url = getBackendUrl() + getResourceNameApiPath(resource);
  return putRequest<Resource, ResultType>(url, resource);
}

export function patchResource<Resource extends IResource, ResultType = Resource>(
  resource: Resource,
  data: unknown,
): IRequestResult<ResultType> {
  const url = getBackendUrl() + getResourceNameApiPath(resource);
  const headers: Record<string, string> = {};
  if (Array.isArray(data)) {
    headers['Content-Type'] = 'application/json-patch+json';
  } else {
    headers['Content-Type'] = 'application/merge-patch+json';
  }
  return patchRequest<unknown, ResultType>(url, data, headers);
}

export function deleteResource<Resource extends IResource>(resource: Resource): IRequestResult {
  if (getResourceName(resource) === undefined)
    throw new ResourceError('Resource name is required.', ResourceErrorCode.BadRequest);
  const url = getBackendUrl() + getResourceNameApiPath(resource);
  return deleteRequest(url);
}

export function getResource<Resource extends IResource>(
  resource: Resource,
  options?: {
    labelSelector?: Record<string, string>;
    fieldSelector?: Record<string, unknown>;
  },
): IRequestResult<Resource> {
  if (getResourceName(resource) === undefined) {
    throw new ResourceError('Resource name is required.', ResourceErrorCode.BadRequest);
  }

  let url = getBackendUrl() + getResourceNameApiPath(resource);

  let queryString = undefined;

  if (options?.labelSelector) {
    const labels: string[] = [];
    for (const key in options.labelSelector) {
      const value = options.labelSelector[key] !== undefined ? options.labelSelector[key] : '';
      labels.push(`${key}=${value}`);
    }
    queryString = 'labelSelector=' + labels.map((label) => label).join(',');
  }

  if (options?.fieldSelector) {
    const fields: string[] = [];
    for (const key in options.fieldSelector) {
      const value = options.fieldSelector[key] !== undefined ? options.fieldSelector[key] : '';
      fields.push(`${key}=${value}`);
    }
    if (queryString) queryString += '&';
    else queryString = '';
    queryString += 'fieldSelector=' + fields.map((field) => field).join(',');
  }

  if (queryString) url += '?' + queryString;

  return getRequest<Resource>(url);
}

export function listResources<Resource extends IResource>(
  resource: { apiVersion: string; kind: string },
  labels?: string[],
  query?: Record<string, string>,
): IRequestResult<Resource[]> {
  let url = getBackendUrl() + getResourceApiPath(resource);
  if (labels) {
    url += '?labelSelector=' + labels.join(',');
    if (query)
      url += `&${Object.keys(query)
        .map((key) => `${key}=${query[key]}`)
        .join('&')}`;
  } else {
    if (query)
      url += `?${Object.keys(query)
        .map((key) => `${key}=${query[key]}`)
        .join('&')}`;
  }
  const result = getRequest<ResourceList<Resource>>(url);
  return {
    promise: result.promise.then((result) => {
      if (Array.isArray(result.items)) {
        return (result.items as Resource[]).map((item) => ({
          ...item,
          ...{
            apiVersion: resource.apiVersion,
            kind: resource.kind,
          },
        }));
      } else {
        return [];
      }
    }),
    abort: result.abort,
  };
}

export function listClusterResources<Resource extends IResource>(
  resource: { apiVersion: string; kind: string },
  labels?: string[],
): IRequestResult<Resource[]> {
  let url = getBackendUrl() + getResourceApiPath(resource);
  if (labels) url += '?labelSelector=' + labels.join(',');
  const result = getRequest<ResourceList<Resource>>(url);
  return {
    promise: result.promise.then((result) => result.items as Resource[]),
    abort: result.abort,
  };
}

export function listNamespacedResources<Resource extends IResource>(
  resource: {
    apiVersion: string;
    kind: string;
    metadata: { namespace: string };
  },
  labels?: string[],
): IRequestResult<Resource[]> {
  let url = getBackendUrl() + getResourceApiPath(resource);
  if (labels) url += '?labelSelector=' + labels.join(',');
  const result = getRequest<ResourceList<Resource>>(url);
  return {
    promise: result.promise.then((result) => result.items as Resource[]),
    abort: result.abort,
  };
}

export function getRequest<ResultT>(url: string): IRequestResult<ResultT> {
  const abortController = new AbortController();
  return {
    promise: fetchGet<ResultT>(url, abortController.signal).then((result) => result.data),
    abort: () => abortController.abort(),
  };
}

export function putRequest<DataT, ResultT>(url: string, data: DataT): IRequestResult<ResultT> {
  const abortController = new AbortController();
  return {
    promise: fetchPut<ResultT>(url, data, abortController.signal).then((result) => result.data),
    abort: () => abortController.abort(),
  };
}

export function postRequest<DataT, ResultT>(url: string, data: DataT): IRequestResult<ResultT> {
  const abortController = new AbortController();
  return {
    promise: fetchPost<ResultT>(url, data, abortController.signal).then((result) => result.data),
    abort: () => abortController.abort(),
  };
}

export function patchRequest<DataT, ResultT>(
  url: string,
  data: DataT,
  headers?: Record<string, string>,
): IRequestResult<ResultT> {
  const abortController = new AbortController();
  return {
    promise: fetchPatch<ResultT>(url, data, abortController.signal, headers).then(
      (result) => result.data,
    ),
    abort: () => abortController.abort(),
  };
}

export function deleteRequest(url: string): IRequestResult {
  const abortController = new AbortController();
  return {
    promise: fetchDelete(url, abortController.signal),
    abort: () => abortController.abort(),
  };
}

// --- FETCH FUNCTIONS ---

export function fetchGet<T = unknown>(url: string, signal: AbortSignal) {
  return fetchRetry<T>({
    method: 'GET',
    url,
    signal,
    retries: process.env.NODE_ENV === 'production' ? 2 : 0,
  });
}

export function fetchPut<T = unknown>(url: string, data: unknown, signal: AbortSignal) {
  return fetchRetry<T>({ method: 'PUT', url, signal, data });
}

export function fetchPost<T = unknown>(url: string, data: unknown, signal: AbortSignal) {
  return fetchRetry<T>({ method: 'POST', url, signal, data });
}

export function fetchPatch<T = unknown>(
  url: string,
  data: unknown,
  signal: AbortSignal,
  headers?: Record<string, string>,
) {
  return fetchRetry<T>({ method: 'PATCH', url, signal, data, headers });
}

export function fetchDelete(url: string, signal: AbortSignal) {
  return fetchRetry<unknown>({ method: 'DELETE', url, signal });
}

const navigateToLogin = () => {
  const url = `${getBackendUrl()}/login`;
  console.info('API returned is Unauthorized response. Redirecting to login: ', url);
  if (url.startsWith('http')) {
    window.location.href = url;
  } else {
    window.location.pathname = url;
  }
};

export async function fetchRetry<T>(options: {
  method?: 'GET' | 'PUT' | 'POST' | 'PATCH' | 'DELETE';
  url: string;
  signal: AbortSignal;
  data?: unknown;
  retries?: number;
  delay?: number;
  headers?: Record<string, string>;
  disableRedirectUnauthorizedLogin?: boolean;
}): Promise<{ headers: Headers; status: number; data: T }> {
  let retries =
    options?.retries && Number.isInteger(options.retries) && options.retries >= 0
      ? options.retries
      : 0;
  let delay =
    options?.delay && Number.isInteger(options.delay) && options.delay > 0 ? options.delay : 100;

  const headers: Record<string, string> = options.headers ?? {
    Accept: 'application/json',
  };

  const csrfToken = getCookie('csrf-token');
  if (csrfToken && (options.method ?? 'GET') !== 'GET' && options.url.startsWith('/')) {
    headers['X-CSRFToken'] = csrfToken;
  }

  let fetchBody: string | undefined;
  if (options.data) {
    try {
      fetchBody = JSON.stringify(options.data);
      if (!headers['Content-Type']) {
        headers['Content-Type'] = 'application/json';
      }
    } catch (err) {
      throw new ResourceError(`Invalid body object for request`, ResourceErrorCode.BadRequest);
    }
  }

  // eslint-disable-next-line no-constant-condition
  while (true) {
    let response: Response | undefined;
    try {
      response = await fetch(options.url, {
        method: options.method ?? 'GET',
        credentials: 'include',
        headers,
        body: fetchBody,
        signal: options.signal,
        redirect: 'manual',
        // mode: "cors",
      });
    } catch (err) {
      if (options.signal.aborted) {
        throw new ResourceError(`Request aborted`, ResourceErrorCode.RequestAborted);
      }

      if (retries === 0) {
        const errCode = (err as { code?: number | string } | undefined)?.code;
        if (err instanceof Error) {
          if (typeof errCode === 'string') {
            switch (errCode) {
              case 'ETIMEDOUT':
                throw new ResourceError('Request timeout.', ResourceErrorCode.Timeout);
              case 'ECONNRESET':
                throw new ResourceError(
                  'Request connection reset.',
                  ResourceErrorCode.ConnectionReset,
                );
              case 'ENOTFOUND':
                throw new ResourceError('Resource not found.', ResourceErrorCode.NotFound);
              default:
                throw new ResourceError(
                  `Unknown error. code: ${errCode}`,
                  ResourceErrorCode.Unknown,
                );
            }
          } else if (typeof errCode === 'number') {
            if (ResourceErrorCodes.includes(errCode)) {
              throw new ResourceError(err.message, errCode);
            } else {
              throw new ResourceError(`Unknown error. code: ${errCode}`, ResourceErrorCode.Unknown);
            }
          } else if (err.message === 'Network Error') {
            throw new ResourceError('Network error', ResourceErrorCode.NetworkError);
          }
        }
        console.log(err);
        throw new ResourceError(`Unknown error. code: ${errCode}`, ResourceErrorCode.Unknown);
      }
    }

    if (response) {
      let responseData: T | string | undefined = undefined;
      // Use includes() to identify text/plain because the header can have more text (ex: charset=..)
      if (!response.headers.get('content-type')?.includes('text/plain')) {
        try {
          responseData = (await response.json()) as T;
        } catch {
          console.error('Error getting resource json response.');
        }
      } else {
        try {
          responseData = await response.text();
        } catch {
          console.error('Error getting resource text response.');
        }
      }

      if ((responseData as unknown as Status)?.kind === StatusKind) {
        const status = responseData as unknown as Status;
        if (status.status !== 'Success') {
          if (status.code === 401) {
            // 401 is returned from kubernetes in a Status object if token is not valid
            navigateToLogin();
            throw new ResourceError(status.message as string, status.code as number);
          } else if (ResourceErrorCodes.includes(status.code as number)) {
            throw new ResourceError(status.message as string, status.code as number);
          } else {
            throw new ResourceError('Unknown error.', ResourceErrorCode.Unknown);
          }
        }
      }

      if (response.status < 300) {
        return {
          headers: response.headers,
          status: response.status,
          data: responseData as T,
        };
      }

      switch (response.status) {
        case 302: // 302 is returned when token is valid but logged out
        case 401: // 401 is returned from the backend if no token cookie is on request
          if (!options.disableRedirectUnauthorizedLogin) {
            navigateToLogin();
          }
          throw new ResourceError('Unauthorized', ResourceErrorCode.Unauthorized);
        case 404:
          throw new ResourceError('Unauthorized', ResourceErrorCode.NotFound);
        case 408: // Request Timeout
        case 429: // Too Many Requests
        case 500: // Internal Server Error
        case 502: // Bad Gateway
        case 503: // Service Unavailable
        case 504: // Gateway Timeout
        case 522: // Connection timed out
        case 524: // A Timeout Occurred
          try {
            const retryAfter = Number(response.headers.get('retry-after'));
            if (Number.isInteger(retryAfter)) delay = retryAfter;
          } catch {
            console.info('Request timeout.');
          }
          break;

        default:
          retries = 0;
          break;
      }

      if (retries === 0) {
        if (ResourceErrorCodes.includes(response.status)) {
          throw new ResourceError(response.statusText, response.status);
        } else {
          throw new ResourceError(
            `Request failed with status code ${response.status}`,
            ResourceErrorCode.Unknown,
          );
        }
      }
    }

    const ms = delay;
    await new Promise((resolve) => setTimeout(resolve, ms));
    delay *= 2;
    retries--;
  }
}
