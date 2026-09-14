import jwt from "jsonwebtoken";
import type { UserRole } from "@prisma/client";
import { env } from "../config";

export type AuthTokenPayload = {
  sub: string;
  email: string;
  role: UserRole;
  firebaseUid: string;
};

export function signAccessToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions["expiresIn"],
  });
}

export function verifyAccessToken(token: string): AuthTokenPayload {
  return jwt.verify(token, env.JWT_SECRET) as AuthTokenPayload;
}
