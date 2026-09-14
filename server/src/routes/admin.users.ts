import { Router } from "express";
import { prisma } from "../db/client";
import { requireAuth, requireAdmin, type AuthedRequest } from "../middleware/auth";
import { getFirebaseAdmin } from "../services/firebase";

export const adminUsersRouter = Router();

adminUsersRouter.use(requireAuth, requireAdmin);

adminUsersRouter.get("/", async (_req, res) => {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: "desc" },
    select: {
      id: true,
      email: true,
      displayName: true,
      role: true,
      createdAt: true,
      firebaseUid: true,
    },
  });
  res.json({ users });
});

adminUsersRouter.post("/:id/grant-admin", async (req: AuthedRequest, res) => {
  const id = String(req.params.id);
  try {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      res.status(404).json({ error: "User not found" });
      return;
    }

    const updated = await prisma.user.update({
      where: { id },
      data: { role: "admin" },
    });

    let claimSet = false;
    const admin = getFirebaseAdmin();
    if (admin && !updated.firebaseUid.startsWith("dev:")) {
      const existing = await admin.auth().getUser(updated.firebaseUid);
      await admin.auth().setCustomUserClaims(updated.firebaseUid, {
        ...(existing.customClaims ?? {}),
        admin: true,
      });
      claimSet = true;
    }

    res.json({
      user: {
        id: updated.id,
        email: updated.email,
        displayName: updated.displayName,
        role: updated.role,
      },
      claimSet,
      message: claimSet
        ? "Admin granted. User should sign out/in to refresh Firebase claims."
        : "Postgres role set to admin. Firebase claim skipped (dev user or Admin SDK not configured).",
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to grant admin" });
  }
});
