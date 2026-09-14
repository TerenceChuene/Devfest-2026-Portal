import { Router } from "express";
import { z } from "zod";
import { env } from "../config";
import { prisma } from "../db/client";
import { requireAuth, type AuthedRequest } from "../middleware/auth";
import { verifyFirebaseIdToken } from "../services/firebase";
import { signAccessToken } from "../services/jwt";

export const authRouter = Router();

const sessionBodySchema = z
  .object({
    idToken: z.string().min(1).optional(),
    devEmail: z.string().email().optional(),
    displayName: z.string().optional(),
  })
  .refine((body) => Boolean(body.idToken || body.devEmail), {
    message: "idToken or devEmail is required",
  });

authRouter.post("/session", async (req, res) => {
  const parsed = sessionBodySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const { idToken, devEmail, displayName } = parsed.data;

  try {
    let firebaseUid: string;
    let email: string;
    let name: string | null = displayName ?? null;
    let avatarUrl: string | null = null;

    if (devEmail) {
      const bypassHeader = req.headers["x-dev-bypass"];
      if (bypassHeader !== env.AUTH_DEV_BYPASS) {
        res.status(403).json({ error: "Invalid dev bypass header" });
        return;
      }
      firebaseUid = `dev:${devEmail.toLowerCase()}`;
      email = devEmail.toLowerCase();
      name = displayName ?? email.split("@")[0] ?? email;
    } else {
      const decoded = await verifyFirebaseIdToken(idToken!);
      firebaseUid = decoded.uid;
      email = (decoded.email ?? "").toLowerCase();
      if (!email) {
        res.status(400).json({ error: "Firebase token is missing an email" });
        return;
      }
      name = decoded.name ?? displayName ?? null;
      avatarUrl = typeof decoded.picture === "string" ? decoded.picture : null;
    }

    const user = await prisma.user.upsert({
      where: { firebaseUid },
      create: {
        firebaseUid,
        email,
        displayName: name,
        avatarUrl,
        role: "attendee",
      },
      update: {
        email,
        displayName: name ?? undefined,
        avatarUrl: avatarUrl ?? undefined,
      },
    });

    const accessToken = signAccessToken({
      sub: user.id,
      email: user.email,
      role: user.role,
      firebaseUid: user.firebaseUid,
    });

    res.json({
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: user.role,
      },
    });
  } catch (error) {
    console.error("POST /api/auth/session failed:", error);
    res.status(401).json({ error: "Unable to establish session" });
  }
});

authRouter.get("/me", requireAuth, async (req: AuthedRequest, res) => {
  const user = req.user!;
  res.json({
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    role: user.role,
  });
});
