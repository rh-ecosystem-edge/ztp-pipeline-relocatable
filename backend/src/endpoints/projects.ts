import { Request, Response } from "express";
import { unauthorized } from "../k8s/respond";
import { getToken } from "../k8s/token";

export const projects = (req: Request, res: Response) => {
  const token = getToken(req);
  if (!token) return unauthorized(req, res);

  res.json({ token });
};
