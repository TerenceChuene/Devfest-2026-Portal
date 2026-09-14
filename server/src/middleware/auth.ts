import type { NextFunction, Request, Response } from "express";
import type { User } from "@prisma/client";
import { prisma } from "../db/client";
import { verifyAccessToken } from "../services/jwt";

export type AuthedRequest = Request & {
  user?: User;
  token?: string;
};

///requireAuth middleware to check if the user is authenticated
///if the user is not authenticated, return a 401 error
///if the user is authenticated, set the user and token in the request object
///and call the next middleware
export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing Bearer token" });
    return;
  }
//get the token from the header
  const token = header.slice("Bearer ".length).trim();
  try {
    //verify the token
    const payload = verifyAccessToken(token);
    //find the user by the user id
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    //if the user is not found, return a 401 error
    if (!user) {
      res.status(401).json({ error: "User not found" });
      return;
    }
    //set the user and token in the request object
    req.user = user;
    req.token = token;
    next();
  } catch {
    //if the token is invalid or expired, return a 401 error
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

///requireAdmin middleware to check if the user is an admin
///if the user is not an admin, return a 403 error
///if the user is an admin, call the next middleware
export function requireAdmin(req: AuthedRequest, res: Response, next: NextFunction) {
  if (!req.user) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  //check if the user is an admin
  //if the user is not an admin, return a 403 error
  if (req.user.role !== "admin") {
    res.status(403).json({ error: "Admin role required" });
    return;
  }
  next();
}
