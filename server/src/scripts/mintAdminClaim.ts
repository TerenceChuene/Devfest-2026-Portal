/**
 * Bootstrap admin custom claim after manually setting users.role = 'admin' in Postgres.
 *
 * Usage:
 *   npm run mint-admin -- --email you@example.com
 *
 * Requires Firebase Admin credentials. Updates Firebase custom claims { admin: true }
 * and confirms the Postgres role is admin.
 */
import path from "node:path";
import dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });
dotenv.config();

import { prisma } from "../db/client";
import { getFirebaseAdmin } from "../services/firebase";

function getArg(flag: string): string | undefined {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return undefined;
  return process.argv[idx + 1];
}

async function main() {
  const email = getArg("--email")?.toLowerCase();
  if (!email) {
    console.error("Usage: npm run mint-admin -- --email you@example.com");
    process.exit(1);
  }

  const user = await prisma.user.findFirst({ where: { email } });
  if (!user) {
    console.error(`No user found with email ${email}. Sign in once first.`);
    process.exit(1);
  }

  if (user.role !== "admin") {
    await prisma.user.update({
      where: { id: user.id },
      data: { role: "admin" },
    });
    console.log(`Updated Postgres role to admin for ${email}`);
  } else {
    console.log(`Postgres role already admin for ${email}`);
  }

  const admin = getFirebaseAdmin();
  if (!admin) {
    console.warn(
      "Firebase Admin not configured — Postgres role is admin, but custom claim was not set.",
    );
    console.warn("Configure FIREBASE_ADMIN_SDK_JSON or FIREBASE_ADMIN_SDK_PATH and re-run.");
    process.exit(0);
  }

  if (user.firebaseUid.startsWith("dev:")) {
    console.warn("Dev bypass user — skipping Firebase custom claim.");
    process.exit(0);
  }

  const existing = await admin.auth().getUser(user.firebaseUid);
  const claims = { ...(existing.customClaims ?? {}), admin: true };
  await admin.auth().setCustomUserClaims(user.firebaseUid, claims);
  console.log(`Set Firebase custom claim admin=true for ${email} (${user.firebaseUid})`);
  console.log("Ask the user to sign out and sign back in so the ID token refreshes.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
