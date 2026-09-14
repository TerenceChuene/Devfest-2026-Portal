import { Router } from "express";
import { requireAuth, type AuthedRequest } from "../middleware/auth";
import { getEventLeaderboard, getSessionLeaderboard } from "../services/leaderboard";
import { prisma } from "../db/client";

export const leaderboardRouter = Router();

leaderboardRouter.get("/sessions/:id/leaderboard", requireAuth, async (req: AuthedRequest, res) => {
  const limit = Number(req.query.limit ?? (req.user?.role === "admin" ? 50 : 10));
  try {
    const session = await prisma.session.findUnique({ where: { id: String(req.params.id) } });
    if (!session) {
      res.status(404).json({ error: "Session not found" });
      return;
    }
    const board = await getSessionLeaderboard({
      sessionId: session.id,
      userId: req.user!.id,
      limit: Number.isFinite(limit) ? limit : 10,
    });
    res.json({
      sessionId: session.id,
      eventId: session.eventId,
      title: session.title,
      ...board,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to load session leaderboard" });
  }
});

leaderboardRouter.get("/events/:eventId/leaderboard", requireAuth, async (req: AuthedRequest, res) => {
  const limit = Number(req.query.limit ?? (req.user?.role === "admin" ? 50 : 10));
  try {
    const event = await prisma.event.findUnique({ where: { id: String(req.params.eventId) } });
    if (!event) {
      res.status(404).json({ error: "Event not found" });
      return;
    }
    const board = await getEventLeaderboard({
      eventId: event.id,
      userId: req.user!.id,
      limit: Number.isFinite(limit) ? limit : 10,
    });
    res.json({
      eventId: event.id,
      name: event.name,
      ...board,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Failed to load event leaderboard" });
  }
});
