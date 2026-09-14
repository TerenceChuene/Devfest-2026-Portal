import type { Server as HttpServer } from "node:http";
import { Server } from "socket.io";
import { prisma } from "../db/client";
import { verifyAccessToken } from "../services/jwt";
import {
  joinSession,
  QuizError,
  submitAnswer,
} from "../services/quiz";
import { setSocketServer } from "./registry";

type SocketData = {
  userId: string;
};

export function createSocketServer(httpServer: HttpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: true,
      credentials: true,
    },
  });
  setSocketServer(io);

  io.use(async (socket, next) => {
    try {
      const token =
        (socket.handshake.auth?.token as string | undefined) ||
        (typeof socket.handshake.headers.authorization === "string"
          ? socket.handshake.headers.authorization.replace(/^Bearer\s+/i, "")
          : undefined);

      if (!token) {
        next(new Error("Unauthorized"));
        return;
      }

      const payload = verifyAccessToken(token);
      const user = await prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) {
        next(new Error("Unauthorized"));
        return;
      }

      (socket.data as SocketData).userId = user.id;
      next();
    } catch {
      next(new Error("Unauthorized"));
    }
  });

  io.on("connection", (socket) => {
    const userId = (socket.data as SocketData).userId;

    socket.on("join_session", async (payload: { sessionId?: string }, ack?) => {
      try {
        const sessionId = payload?.sessionId;
        if (!sessionId) throw new QuizError("sessionId required", "invalid", 400);

        const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
        const result = await joinSession(sessionId, user);

        await socket.join(`session:${sessionId}`);
        const session = await prisma.session.findUnique({ where: { id: sessionId } });
        if (session) await socket.join(`event:${session.eventId}`);

        socket.emit("session_state", result.sessionState);
        socket.emit("question_ready", result.question);
        if (typeof ack === "function") ack({ ok: true, ...result });
      } catch (error) {
        emitQuizError(socket, error);
        if (typeof ack === "function") {
          ack({
            ok: false,
            error: error instanceof QuizError ? error.message : "join failed",
            code: error instanceof QuizError ? error.code : "error",
          });
        }
      }
    });

    socket.on(
      "submit_answer",
      async (
        payload: { sessionId?: string; questionId?: string; optionId?: string },
        ack?,
      ) => {
        try {
          const { sessionId, questionId, optionId } = payload ?? {};
          if (!sessionId || !questionId || !optionId) {
            throw new QuizError("sessionId, questionId, and optionId are required", "invalid", 400);
          }

          const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
          const result = await submitAnswer({ sessionId, user, questionId, optionId });

          socket.emit("answer_result", result);
          if (result.nextQuestion) {
            socket.emit("question_ready", result.nextQuestion);
          }
          if (typeof ack === "function") ack({ ok: true, ...result });
        } catch (error) {
          emitQuizError(socket, error);
          if (typeof ack === "function") {
            ack({
              ok: false,
              error: error instanceof QuizError ? error.message : "submit failed",
              code: error instanceof QuizError ? error.code : "error",
            });
          }
        }
      },
    );

    socket.on("subscribe_leaderboard", async (payload: { sessionId?: string; eventId?: string }) => {
      if (payload?.sessionId) {
        await socket.join(`session:${payload.sessionId}`);
        const session = await prisma.session.findUnique({
          where: { id: payload.sessionId },
          select: { eventId: true },
        });
        if (session) await socket.join(`event:${session.eventId}`);
      }
      if (payload?.eventId) await socket.join(`event:${payload.eventId}`);
    });
  });

  return io;
}

function emitQuizError(socket: import("socket.io").Socket, error: unknown) {
  if (!(error instanceof QuizError)) {
    socket.emit("error_message", { error: "Unexpected error" });
    return;
  }
  if (error.code === "quiz_closed") {
    socket.emit("quiz_closed", { reason: error.message });
    return;
  }
  if (error.code === "already_played") {
    socket.emit("already_played", { sessionId: null });
    return;
  }
  socket.emit("error_message", { error: error.message, code: error.code });
}
