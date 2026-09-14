import { Router } from "express";
import { z } from "zod";
import { requireAuth, type AuthedRequest } from "../middleware/auth";
import {
  getMyProgress,
  getSessionByCode,
  joinSession,
  QuizError,
  submitAnswer,
} from "../services/quiz";

export const sessionsRouter = Router();

function handleQuizError(res: import("express").Response, error: unknown) {
  if (error instanceof QuizError) {
    res.status(error.status).json({ error: error.message, code: error.code });
    return;
  }
  console.error(error);
  res.status(500).json({ error: "Internal server error" });
}

sessionsRouter.get("/by-code/:code", requireAuth, async (req, res) => {
  try {
    const code = String(req.params.code ?? "");
    const session = await getSessionByCode(code);
    res.json({ session });
  } catch (error) {
    handleQuizError(res, error);
  }
});

sessionsRouter.post("/:id/join", requireAuth, async (req: AuthedRequest, res) => {
  try {
    const result = await joinSession(String(req.params.id), req.user!);
    res.json(result);
  } catch (error) {
    handleQuizError(res, error);
  }
});

sessionsRouter.get("/:id/me", requireAuth, async (req: AuthedRequest, res) => {
  try {
    const progress = await getMyProgress(String(req.params.id), req.user!);
    res.json(progress);
  } catch (error) {
    handleQuizError(res, error);
  }
});

const answerSchema = z.object({
  questionId: z.string().uuid(),
  optionId: z.string().uuid(),
});

sessionsRouter.post("/:id/answer", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = answerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }

  try {
    const result = await submitAnswer({
      sessionId: String(req.params.id),
      user: req.user!,
      questionId: parsed.data.questionId,
      optionId: parsed.data.optionId,
    });
    res.json(result);
  } catch (error) {
    handleQuizError(res, error);
  }
});
