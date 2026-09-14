/**
 * One-shot helper: list Firebase web app config for flutterfire / dart-defines.
 * Usage: npx tsx src/scripts/fetchFirebaseWebConfig.ts
 */
import { GoogleAuth } from "google-auth-library";
import { env } from "../config";

async function main() {
  const keyFile = env.FIREBASE_ADMIN_SDK_PATH;
  if (!keyFile) {
    throw new Error("Set FIREBASE_ADMIN_SDK_PATH");
  }
  const projectId = env.FIREBASE_PROJECT_ID || "devfest2026-2708b";
  const auth = new GoogleAuth({
    keyFile,
    scopes: [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/firebase",
    ],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("Failed to get access token");

  const listRes = await fetch(
    `https://firebase.googleapis.com/v1beta1/projects/${projectId}/webApps`,
    { headers: { Authorization: `Bearer ${token.token}` } },
  );
  const listBody = (await listRes.json()) as {
    apps?: Array<{ name?: string; appId?: string; displayName?: string }>;
    error?: { message?: string };
  };
  if (!listRes.ok) {
    throw new Error(`List webApps failed: ${JSON.stringify(listBody)}`);
  }

  const apps = listBody.apps ?? [];
  if (apps.length === 0) {
    console.log("No web apps found. Create one in Firebase Console → Project settings → Your apps.");
    return;
  }

  for (const app of apps) {
    const appId = app.appId ?? app.name?.split("/").pop();
    if (!appId) continue;
    const cfgRes = await fetch(
      `https://firebase.googleapis.com/v1beta1/projects/${projectId}/webApps/${appId}/config`,
      { headers: { Authorization: `Bearer ${token.token}` } },
    );
    const cfg = await cfgRes.json();
    console.log(`\n# ${app.displayName ?? appId}`);
    console.log(JSON.stringify(cfg, null, 2));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
