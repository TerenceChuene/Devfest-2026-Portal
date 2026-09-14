import type { Question, QuestionOption, Session, SessionParticipant, User } from "@prisma/client";
import { prisma } from "../db/client";
import { normalizeSessionCode } from "./sessionCodes";
import { scoreAnswer } from "./scoring";

export class QuizError extends Error {
  constructor(
    message: string,
    readonly code:
      | "not_found"
      | "quiz_closed"
      | "already_played"
      | "forbidden"
      | "invalid"
      | "duplicate"
      | "not_joined",
    readonly status = 400,
  ) {
    super(message);
    this.name = "QuizError";
  }
}

export type PublicOption = {
  id: string;
  label: string;
  orderIndex: number;
};

export type QuestionReadyPayload = {
  questionId: string;
  prompt: string;
  options: PublicOption[];
  timeLimitSeconds: number;
  serverStartTime: string;
  orderIndex: number;
  totalQuestions: number;
};

export type AnswerResultPayload = {
  questionId: string;
  isCorrect: boolean;
  pointsAwarded: number;
  correctOptionId: string | null;
  completed: boolean;
  totalScore: number;
  nextQuestion?: QuestionReadyPayload;
};

function publicOptions(options: QuestionOption[]): PublicOption[] {
  return [...options]
    .sort((a, b) => a.orderIndex - b.orderIndex)
    .map((option) => ({
      id: option.id,
      label: option.label,
      orderIndex: option.orderIndex,
    }));
}

async function loadSessionQuestions(sessionId: string) {
  return prisma.question.findMany({
    where: { sessionId },
    include: { options: true },
    orderBy: { orderIndex: "asc" },
  });
}

async function participantCount(sessionId: string) {
  return prisma.sessionParticipant.count({ where: { sessionId } });
}

async function ensureQuestionTimer(params: {
  sessionId: string;
  userId: string;
  questionId: string;
}): Promise<Date> {
  const existing = await prisma.participantQuestionTimer.findUnique({
    where: {
      userId_questionId: {
        userId: params.userId,
        questionId: params.questionId,
      },
    },
  });
  if (existing) return existing.startedAt;

  const created = await prisma.participantQuestionTimer.create({
    data: {
      sessionId: params.sessionId,
      userId: params.userId,
      questionId: params.questionId,
    },
  });
  return created.startedAt;
}

function toQuestionReady(
  question: Question & { options: QuestionOption[] },
  totalQuestions: number,
  serverStartTime: Date,
  sessionDefaultSeconds: number,
): QuestionReadyPayload {
  return {
    questionId: question.id,
    prompt: question.prompt,
    options: publicOptions(question.options),
    timeLimitSeconds: question.timeLimitSeconds ?? sessionDefaultSeconds,
    serverStartTime: serverStartTime.toISOString(),
    orderIndex: question.orderIndex,
    totalQuestions,
  };
}

export async function getSessionByCode(code: string) {
  const sessionCode = normalizeSessionCode(code);
  if (sessionCode.length !== 4) {
    throw new QuizError("Pin must be 4 characters", "invalid", 400);
  }

  const session = await prisma.session.findUnique({
    where: { sessionCode },
    include: {
      event: { select: { id: true, name: true, slug: true } },
      _count: { select: { questions: true, participants: true } },
    },
  });

  if (!session) {
    throw new QuizError("Session not found", "not_found", 404);
  }

  return {
    id: session.id,
    title: session.title,
    speakerName: session.speakerName,
    sessionCode: session.sessionCode,
    status: session.status,
    questionTimeLimitSeconds: session.questionTimeLimitSeconds,
    event: session.event,
    questionCount: session._count.questions,
    participantCount: session._count.participants,
  };
}

export async function joinSession(sessionId: string, user: User) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session) throw new QuizError("Session not found", "not_found", 404);

  const existing = await prisma.sessionParticipant.findUnique({
    where: { sessionId_userId: { sessionId, userId: user.id } },
  });

  if (existing?.completedAt) {
    throw new QuizError("Already played", "already_played", 409);
  }

  if (existing) {
    return resumeSession(session, existing, user);
  }

  if (session.status !== "join_open") {
    throw new QuizError("Quiz Closed", "quiz_closed", 403);
  }

  const questions = await loadSessionQuestions(sessionId);
  if (questions.length === 0) {
    throw new QuizError("Session has no questions", "invalid", 400);
  }

  const now = new Date();
  const participant = await prisma.sessionParticipant.create({
    data: {
      sessionId,
      userId: user.id,
      currentOrderIndex: 0,
      quizStartedAt: now,
      totalScore: 0,
    },
  });

  const first = questions[0]!;
  const startedAt = await ensureQuestionTimer({
    sessionId,
    userId: user.id,
    questionId: first.id,
  });

  const count = await participantCount(sessionId);

  return {
    kind: "joined" as const,
    sessionState: {
      status: session.status,
      participantCount: count,
      myProgress: {
        currentOrderIndex: participant.currentOrderIndex,
        totalScore: participant.totalScore,
        completed: false,
      },
    },
    question: toQuestionReady(
      first,
      questions.length,
      startedAt,
      session.questionTimeLimitSeconds,
    ),
  };
}

async function resumeSession(
  session: Session,
  participant: SessionParticipant,
  user: User,
) {
  const questions = await loadSessionQuestions(session.id);
  const count = await participantCount(session.id);

  if (participant.currentOrderIndex >= questions.length) {
    throw new QuizError("Already played", "already_played", 409);
  }

  const current = questions[participant.currentOrderIndex];
  if (!current) {
    throw new QuizError("Already played", "already_played", 409);
  }

  const startedAt = await ensureQuestionTimer({
    sessionId: session.id,
    userId: user.id,
    questionId: current.id,
  });

  return {
    kind: "resumed" as const,
    sessionState: {
      status: session.status,
      participantCount: count,
      myProgress: {
        currentOrderIndex: participant.currentOrderIndex,
        totalScore: participant.totalScore,
        completed: false,
      },
    },
    question: toQuestionReady(
      current,
      questions.length,
      startedAt,
      session.questionTimeLimitSeconds,
    ),
  };
}

export async function getMyProgress(sessionId: string, user: User) {
  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session) throw new QuizError("Session not found", "not_found", 404);

  const participant = await prisma.sessionParticipant.findUnique({
    where: { sessionId_userId: { sessionId, userId: user.id } },
  });

  if (!participant) {
    return {
      joined: false,
      status: session.status,
      sessionId: session.id,
      title: session.title,
      sessionCode: session.sessionCode,
    };
  }

  if (participant.completedAt) {
    return {
      joined: true,
      completed: true,
      status: session.status,
      sessionId: session.id,
      title: session.title,
      sessionCode: session.sessionCode,
      totalScore: participant.totalScore,
      completedAt: participant.completedAt.toISOString(),
    };
  }

  const resumed = await resumeSession(session, participant, user);
  return {
    joined: true,
    completed: false,
    status: session.status,
    sessionId: session.id,
    title: session.title,
    sessionCode: session.sessionCode,
    currentOrderIndex: resumed.sessionState.myProgress?.currentOrderIndex,
    totalScore: resumed.sessionState.myProgress?.totalScore,
    question: resumed.question,
  };
}

export async function submitAnswer(params: {
  sessionId: string;
  user: User;
  questionId: string;
  optionId: string;
}): Promise<AnswerResultPayload> {
  const { sessionId, user, questionId, optionId } = params;

  const session = await prisma.session.findUnique({ where: { id: sessionId } });
  if (!session) throw new QuizError("Session not found", "not_found", 404);

  const participant = await prisma.sessionParticipant.findUnique({
    where: { sessionId_userId: { sessionId, userId: user.id } },
  });
  if (!participant) {
    throw new QuizError("Join the session first", "not_joined", 403);
  }
  if (participant.completedAt) {
    throw new QuizError("Already played", "already_played", 409);
  }

  const existingAnswer = await prisma.quizAnswer.findUnique({
    where: { questionId_userId: { questionId, userId: user.id } },
  });
  if (existingAnswer) {
    throw new QuizError("Already answered this question", "duplicate", 409);
  }

  const questions = await loadSessionQuestions(sessionId);
  const question = questions.find((q) => q.id === questionId);
  if (!question) {
    throw new QuizError("Question not found", "not_found", 404);
  }

  if (question.orderIndex !== participant.currentOrderIndex) {
    throw new QuizError("This is not your current question", "invalid", 400);
  }

  const option = question.options.find((o) => o.id === optionId);
  if (!option) {
    throw new QuizError("Invalid option", "invalid", 400);
  }

  const timer = await prisma.participantQuestionTimer.findUnique({
    where: { userId_questionId: { userId: user.id, questionId } },
  });
  if (!timer) {
    throw new QuizError("Question timer missing", "invalid", 400);
  }

  const answeredAt = new Date();
  const responseMs = Math.max(0, answeredAt.getTime() - timer.startedAt.getTime());
  const timeLimitSeconds = question.timeLimitSeconds ?? session.questionTimeLimitSeconds;
  const isCorrect = option.isCorrect;
  const pointsAwarded = scoreAnswer(isCorrect, responseMs, timeLimitSeconds);
  const correctOption = question.options.find((o) => o.isCorrect) ?? null;

  const nextIndex = participant.currentOrderIndex + 1;
  const completed = nextIndex >= questions.length;

  const result = await prisma.$transaction(async (tx) => {
    await tx.quizAnswer.create({
      data: {
        sessionId,
        questionId,
        userId: user.id,
        optionId,
        isCorrect,
        responseMs,
        pointsAwarded,
        answeredAt,
      },
    });

    const updated = await tx.sessionParticipant.update({
      where: { sessionId_userId: { sessionId, userId: user.id } },
      data: {
        currentOrderIndex: nextIndex,
        totalScore: { increment: pointsAwarded },
        completedAt: completed ? answeredAt : null,
      },
    });

    return updated;
  });

  try {
    const { addScore, reconcileSessionScores } = await import("./leaderboard");
    await addScore({
      sessionId,
      eventId: session.eventId,
      userId: user.id,
      points: pointsAwarded,
    });
    if (completed) {
      await reconcileSessionScores(sessionId);
    }
  } catch (error) {
    console.error("leaderboard update failed", error);
  }

  let nextQuestion: QuestionReadyPayload | undefined;
  if (!completed) {
    const next = questions[nextIndex]!;
    const startedAt = await ensureQuestionTimer({
      sessionId,
      userId: user.id,
      questionId: next.id,
    });
    nextQuestion = toQuestionReady(
      next,
      questions.length,
      startedAt,
      session.questionTimeLimitSeconds,
    );
  }

  return {
    questionId,
    isCorrect,
    pointsAwarded,
    correctOptionId: correctOption?.id ?? null,
    completed,
    totalScore: result.totalScore,
    nextQuestion,
  };
}

export async function openJoin(sessionId: string) {
  const session = await prisma.session.update({
    where: { id: sessionId },
    data: {
      status: "join_open",
      openedAt: new Date(),
      closedAt: null,
    },
  });
  return session;
}

export async function closeSession(sessionId: string) {
  const session = await prisma.session.update({
    where: { id: sessionId },
    data: {
      status: "closed",
      closedAt: new Date(),
    },
  });
  try {
    const { reconcileSessionScores } = await import("./leaderboard");
    await reconcileSessionScores(sessionId);
  } catch (error) {
    console.error("leaderboard reconcile on close failed", error);
  }
  return session;
}
