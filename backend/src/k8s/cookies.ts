import { Request, Response } from "express"

export function parseCookies(req: Request): Record<string, string> {
  const cookieHeader = req.headers.cookie
  if (cookieHeader !== undefined) {
      const cookies: { [key: string]: string } = {}
      const cookieArray = cookieHeader.split(';').map((cookie) => cookie.trim().split('='))
      for (const cookie of cookieArray) {
          if (cookie.length === 2) {
              cookies[cookie[0]] = cookie[1]
          }
      }
      return cookies
  }
  return {}
}

export function setCookie(res: Response, cookie: string, value: string, path?: string): void {
  res.setHeader('Set-Cookie', `${cookie}=${value}; Secure; HttpOnly; Path=${path ? path : '/'}`)
}

export function deleteCookie(res: Response, cookie: string, path?: string): void {
  res.setHeader('Set-Cookie', `${cookie}=; Secure; HttpOnly; Path=${path ? path : '/'}` + `; max-age=0`)
}
