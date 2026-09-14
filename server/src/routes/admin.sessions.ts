import { Router } from "express";
import { z } from "zod";
import { prisma } from "../db/client";
import { requireAuth, requireAdmin, type AuthedRequest } from "../middleware/auth";
import { allocateUniqueSessionCode } from "../services/sessionCodes";
import { closeSession, openJoin, QuizError } from "../services/quiz";
import { sessionPublicPayload } from "../services/joinLinks";
import { generateQuestionsFromNotes } from "../services/aiParsing";
import { parseQuestionsCsv, saveQuestionsBodySchema } from "../services/csvQuestions";

export const adminSessionsRouter = Router();

adminSessionsRouter.use(requireAuth, requireAdmin);

function handleError(res: import("express").Response, error: unknown) {
  if (error instanceof QuizError) {
    res.status(error.status).json({ error: error.message, code: error.code });
    return;
  }

  const errCode =
    typeof error === "object" && error && "code" in error
      ? String((error as { code: unknown }).code)
      : "";

  if (errCode === "P2025") {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  if (errCode === "gemini_unconfigured") {
    res.status(503).json({ error: (error as Error).message, code: errCode });
    return;
  }
  if (errCode === "gemini_invalid") {
    const err = error as Error & { raw?: string; details?: unknown };
    res.status(422).json({
      error: err.message,
      code: errCode,
      rawModelOutput: err.raw,
      details: err.details,
    });
    return;
  }
  console.error(error);
  res.status(500).json({ error: error instanceof Error ? error.message : "Internal server error" });
}

const createSessionSchema = z.object({
  eventId: z.string().uuid(),
  title: z.string().min(1).max(200),
  speakerName: z.string().max(200).optional().nullable(),
  questionTimeLimitSeconds: z.number().int().min(5).max(300).optional(),
});

const patchSessionSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  speakerName: z.string().max(200).optional().nullable(),
  questionTimeLimitSeconds: z.number().int().min(5).max(300).optional(),
});

adminSessionsRouter.get("/", async (req, res) => {
  try {
    const eventId = typeof req.query.eventId === "string" ? req.query.eventId : undefined;
    const sessions = await prisma.session.findMany({
      where: eventId ? { eventId } : undefined,
      orderBy: { createdAt: "desc" },
      include: {
        event: { select: { id: true, name: true, slug: true } },
        _count: { select: { questions: true, participants: true } },
      },
    });
    res.json({
      sessions: sessions.map((session) =>
        sessionPublicPayload({
          id: session.id,
          eventId: session.eventId,
          title: session.title,
          speakerName: session.speakerName,
          sessionCode: session.sessionCode,
          status: session.status,
          openedAt: session.openedAt,
          closedAt: session.closedAt,
          questionTimeLimitSeconds: session.questionTimeLimitSeconds,
          createdAt: session.createdAt,
          event: session.event,
          questionCount: session._count.questions,
          participantCount: session._count.participants,
        }),
      ),
    });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/", async (req: AuthedRequest, res) => {
  const parsed = createSessionSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const event = await prisma.event.findUnique({ where: { id: parsed.data.eventId } });
    if (!event) {
      res.status(404).json({ error: "Event not found" });
      return;
    }

    const sessionCode = await allocateUniqueSessionCode();
    const session = await prisma.session.create({
      data: {
        eventId: parsed.data.eventId,
        title: parsed.data.title,
        speakerName: parsed.data.speakerName ?? null,
        sessionCode,
        questionTimeLimitSeconds: parsed.data.questionTimeLimitSeconds ?? 15,
        createdById: req.user!.id,
        status: "draft",
      },
      include: {
        event: { select: { id: true, name: true, slug: true } },
        _count: { select: { questions: true, participants: true } },
      },
    });

    res.status(201).json({
      session: sessionPublicPayload({
        ...session,
        questionCount: session._count.questions,
        participantCount: session._count.participants,
      }),
    });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/seed-demo", async (req: AuthedRequest, res) => {
  try {
    let event = await prisma.event.findFirst({ where: { slug: "devfest-demo" } });
    if (!event) {
      event = await prisma.event.create({
        data: { name: "DevFest Demo", slug: "devfest-demo" },
      });
    }

    const sessionCode = await allocateUniqueSessionCode();
    const session = await prisma.session.create({
      data: {
        eventId: event.id,
        title: "Demo Quiz",
        speakerName: "Demo Speaker",
        sessionCode,
        status: "join_open",
        openedAt: new Date(),
        questionTimeLimitSeconds: 15,
        createdById: req.user!.id,
        questions: {
          create: [
            {
              prompt: "What does GDG stand for?",
              orderIndex: 0,
              options: {
                create: [
                  { label: "Google Developer Group", isCorrect: true, orderIndex: 0 },
                  { label: "Global Data Grid", isCorrect: false, orderIndex: 1 },
                  { label: "General Design Guild", isCorrect: false, orderIndex: 2 },
                  { label: "Geek Developer Guild", isCorrect: false, orderIndex: 3 },
                ],
              },
            },
            {
              prompt: "Which database stores sessions and questions?",
              orderIndex: 1,
              options: {
                create: [
                  { label: "MongoDB", isCorrect: false, orderIndex: 0 },
                  { label: "PostgreSQL", isCorrect: true, orderIndex: 1 },
                  { label: "Firestore", isCorrect: false, orderIndex: 2 },
                  { label: "SQLite", isCorrect: false, orderIndex: 3 },
                ],
              },
            },
            {
              prompt: "Which store backs live scoring bursts?",
              orderIndex: 2,
              options: {
                create: [
                  { label: "Redis", isCorrect: true, orderIndex: 0 },
                  { label: "Memcached", isCorrect: false, orderIndex: 1 },
                  { label: "LocalStorage", isCorrect: false, orderIndex: 2 },
                  { label: "S3", isCorrect: false, orderIndex: 3 },
                ],
              },
            },
          ],
        },
      },
      include: {
        event: true,
        _count: { select: { questions: true, participants: true } },
      },
    });

    res.status(201).json({
      session: sessionPublicPayload({
        id: session.id,
        title: session.title,
        sessionCode: session.sessionCode,
        status: session.status,
        event: session.event,
        questionCount: session._count.questions,
        participantCount: session._count.participants,
      }),
    });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.get("/:id", async (req, res) => {
  try {
    const session = await prisma.session.findUnique({
      where: { id: String(req.params.id) },
      include: {
        event: true,
        questions: { include: { options: true }, orderBy: { orderIndex: "asc" } },
        _count: { select: { participants: true } },
      },
    });
    if (!session) {
      res.status(404).json({ error: "Session not found" });
      return;
    }
    res.json({
      session: sessionPublicPayload({
        ...session,
        participantCount: session._count.participants,
      }),
    });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.patch("/:id", async (req, res) => {
  const parsed = patchSessionSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const session = await prisma.session.update({
      where: { id: String(req.params.id) },
      data: {
        title: parsed.data.title,
        speakerName: parsed.data.speakerName === undefined ? undefined : parsed.data.speakerName,
        questionTimeLimitSeconds: parsed.data.questionTimeLimitSeconds,
      },
      include: {
        event: true,
        _count: { select: { questions: true, participants: true } },
      },
    });
    res.json({
      session: sessionPublicPayload({
        ...session,
        questionCount: session._count.questions,
        participantCount: session._count.participants,
      }),
    });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.delete("/:id", async (req, res) => {
  try {
    await prisma.session.delete({ where: { id: String(req.params.id) } });
    res.status(204).send();
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/:id/open-join", async (req, res) => {
  try {
    const id = String(req.params.id);
    const existing = await prisma.session.findUnique({
      where: { id },
      include: { _count: { select: { questions: true } } },
    });
    if (!existing) {
      res.status(404).json({ error: "Session not found" });
      return;
    }
    if (existing._count.questions === 0) {
      res.status(400).json({ error: "Add questions before opening joins" });
      return;
    }
    const session = await openJoin(id);
    res.json({ session: sessionPublicPayload(session) });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/:id/close", async (req, res) => {
  try {
    const session = await closeSession(String(req.params.id));
    res.json({ session: sessionPublicPayload(session) });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/:id/questions", async (req, res) => {
  const parsed = saveQuestionsBodySchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  const sessionId = String(req.params.id);
  try {
    const session = await prisma.session.findUnique({ where: { id: sessionId } });
    if (!session) {
      res.status(404).json({ error: "Session not found" });
      return;
    }

    const answerCount = await prisma.quizAnswer.count({ where: { sessionId } });
    if (answerCount > 0 && parsed.data.replace) {
      res.status(409).json({
        error: "Cannot replace questions after answers exist",
        code: "questions_locked",
      });
      return;
    }

    const saved = await prisma.$transaction(async (tx) => {
      if (parsed.data.replace) {
        await tx.question.deleteMany({ where: { sessionId } });
      }

      const existingCount = parsed.data.replace
        ? 0
        : await tx.question.count({ where: { sessionId } });

      for (let i = 0; i < parsed.data.questions.length; i += 1) {
        const q = parsed.data.questions[i]!;
        await tx.question.create({
          data: {
            sessionId,
            prompt: q.prompt,
            orderIndex: existingCount + i,
            options: {
              create: q.options.map((option, orderIndex) => ({
                label: option.label,
                isCorrect: option.isCorrect,
                orderIndex,
              })),
            },
          },
        });
      }

      return tx.question.findMany({
        where: { sessionId },
        include: { options: true },
        orderBy: { orderIndex: "asc" },
      });
    });

    res.status(201).json({ questions: saved });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/:id/questions/generate", async (req, res) => {
  const body = z.object({ sourceText: z.string().min(20) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.flatten() });
    return;
  }

  const sessionId = String(req.params.id);
  try {
    const session = await prisma.session.findUnique({ where: { id: sessionId } });
    if (!session) {
      res.status(404).json({ error: "Session not found" });
      return;
    }

    const result = await generateQuestionsFromNotes(body.data.sourceText);
    res.json({ questions: result.questions });
  } catch (error) {
    handleError(res, error);
  }
});

adminSessionsRouter.post("/:id/questions/upload-csv", async (req, res) => {
  const body = z.object({ csvText: z.string().min(1) }).safeParse(req.body);
  if (!body.success) {
    res.status(400).json({ error: body.error.flatten() });
    return;
  }

  try {
    const session = await prisma.session.findUnique({ where: { id: String(req.params.id) } });
    if (!session) {
      res.status(404).json({ error: "Session not found" });
      return;
    }
    const questions = parseQuestionsCsv(body.data.csvText);
    res.json({ questions });
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Invalid CSV" });
  }
});
