import { Request, Response } from "express";

export const ping = (_: Request, res: Response) => {
  res.json({ message: "Hello from server!" });
}