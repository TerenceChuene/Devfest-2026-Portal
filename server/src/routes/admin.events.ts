import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db/client";
import { requireAuth, requireAdmin, type AuthedRequest } from "../middleware/auth";

export const adminEventsRouter = Router();

adminEventsRouter.use(requireAuth, requireAdmin);

function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

const createEventSchema = z.object({
  name: z.string().min(1).max(200),
  slug: z.string().min(1).max(80).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/).optional(),
  startsAt: z.string().datetime().optional().nullable(),
  endsAt: z.string().datetime().optional().nullable(),
});

const patchEventSchema = createEventSchema.partial();

adminEventsRouter.get("/", async (_req, res) => {
  const events = await prisma.event.findMany({
    orderBy: { createdAt: "desc" },
  });
  res.json({ events });
});

adminEventsRouter.post("/", async (req: AuthedRequest, res) => {
  const parsed = createEventSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const { name, startsAt, endsAt } = parsed.data;
  const slug = parsed.data.slug ?? slugify(name);
  if (!slug) {
    res.status(400).json({ error: "Could not derive a valid slug from name" });
    return;
  }

  try {
    const event = await prisma.event.create({
      data: {
        name,
        slug,
        startsAt: startsAt ? new Date(startsAt) : null,
        endsAt: endsAt ? new Date(endsAt) : null,
      },
    });
    res.status(201).json({ event });
  } catch (error: unknown) {
    const code = typeof error === "object" && error && "code" in error ? (error as { code: string }).code : "";
    if (code === "P2002") {
      res.status(409).json({ error: "An event with that slug already exists" });
      return;
    }
    console.error("POST /api/admin/events failed:", error);
    res.status(500).json({ error: "Failed to create event" });
  }
});

adminEventsRouter.patch("/:id", async (req, res) => {
  const parsed = patchEventSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const data = parsed.data;
  try {
    const event = await prisma.event.update({
      where: { id: req.params.id },
      data: {
        name: data.name,
        slug: data.slug,
        startsAt: data.startsAt === undefined ? undefined : data.startsAt ? new Date(data.startsAt) : null,
        endsAt: data.endsAt === undefined ? undefined : data.endsAt ? new Date(data.endsAt) : null,
      },
    });
    res.json({ event });
  } catch (error: unknown) {
    const code = typeof error === "object" && error && "code" in error ? (error as { code: string }).code : "";
    if (code === "P2025") {
      res.status(404).json({ error: "Event not found" });
      return;
    }
    if (code === "P2002") {
      res.status(409).json({ error: "An event with that slug already exists" });
      return;
    }
    console.error("PATCH /api/admin/events/:id failed:", error);
    res.status(500).json({ error: "Failed to update event" });
  }
});
