import fs from "node:fs";
import path from "node:path";
import admin from "firebase-admin";
import { env } from "../config";

let initialized = false;

/** Resolve Admin SDK path relative to the server package root (…/server). */
function resolveAdminSdkPath(sdkPath: string): string {
  if (path.isAbsolute(sdkPath)) return sdkPath;
  return path.resolve(__dirname, "../..", sdkPath);
}

export function getFirebaseAdmin(): typeof admin | null {
  if (initialized) {
    return admin.apps.length ? admin : null;
  }

  initialized = true;

  try {
    if (env.FIREBASE_ADMIN_SDK_JSON) {
      const credentials = JSON.parse(env.FIREBASE_ADMIN_SDK_JSON) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId: env.FIREBASE_PROJECT_ID || credentials.projectId,
      });
      return admin;
    }

    if (env.FIREBASE_ADMIN_SDK_PATH) {
      const resolved = resolveAdminSdkPath(env.FIREBASE_ADMIN_SDK_PATH);
      const raw = fs.readFileSync(resolved, "utf8");
      const credentials = JSON.parse(raw) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(credentials),
        projectId: env.FIREBASE_PROJECT_ID || credentials.projectId,
      });
      return admin;
    }
  } catch (error) {
    console.warn("Firebase Admin failed to initialize:", error);
  }

  if (!env.AUTH_DEV_BYPASS) {
    console.warn(
      "Firebase Admin is not configured. Set FIREBASE_ADMIN_SDK_JSON/PATH or AUTH_DEV_BYPASS for local auth.",
    );
  }

  return null;
}

export async function verifyFirebaseIdToken(idToken: string) {
  const app = getFirebaseAdmin();
  if (!app) {
    throw new Error("Firebase Admin is not configured");
  }
  return app.auth().verifyIdToken(idToken);
}
