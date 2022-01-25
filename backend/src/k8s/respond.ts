import { Request, Response } from 'express';
import { constants } from 'http2';

const {
  HTTP_STATUS_OK,
  HTTP_STATUS_CREATED,
  HTTP_STATUS_BAD_REQUEST,
  HTTP_STATUS_UNAUTHORIZED,
  HTTP_STATUS_NOT_FOUND,
  HTTP_STATUS_CONFLICT,
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
} = constants;

export function respond(res: Response, data: unknown, status = 200): void {
  let jsonString: string;
  if (typeof data === 'string') {
    jsonString = data;
  } else if (data instanceof Buffer) {
    jsonString = data.toString();
  } else {
    jsonString = JSON.stringify(data);
  }
  res.writeHead(status, { 'content-type': 'application/json' }).end(jsonString);
}

export function respondOK(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_OK).end();
}

export function respondCreated(res: Response, data: Record<string, unknown>): void {
  if (data) {
    res
      .writeHead(HTTP_STATUS_CREATED, { 'content-type': 'application/json' })
      .end(JSON.stringify(data));
  } else {
    res.writeHead(HTTP_STATUS_CREATED).end();
  }
}

export function redirect(res: Response, location: string): void {
  res.writeHead(302, { location }).end();
}

export function respondBadRequest(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_BAD_REQUEST).end();
}

export function unauthorized(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_UNAUTHORIZED).end();
}

export function notFound(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_NOT_FOUND).end();
}

export function respondConflict(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_CONFLICT).end();
}

export function respondInternalServerError(_req: Request, res: Response): void {
  res.writeHead(HTTP_STATUS_INTERNAL_SERVER_ERROR).end();
}
