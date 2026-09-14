import { env } from "../config";

export function joinUrlForCode(sessionCode: string): string {
  const origin = env.WEB_ORIGIN.replace(/\/$/, "");
  return `${origin}/join?code=${encodeURIComponent(sessionCode)}`;
}

export function sessionPublicPayload<T extends { sessionCode: string; id: string }>(session: T) {
  const joinUrl = joinUrlForCode(session.sessionCode);
  return {
    ...session,
    joinUrl,
    qrPayload: joinUrl,
  };
}
