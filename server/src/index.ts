import { createServer } from "node:http";
import cors from "cors";
import express from "express";
import { env } from "./config";
import { getFirebaseAdmin } from "./services/firebase";
import { initLeaderboardStore, rebuildMissingLeaderboards, isMemoryLeaderboard } from "./services/leaderboard";
import { authRouter } from "./routes/auth";
import { adminEventsRouter } from "./routes/admin.events";
import { adminSessionsRouter } from "./routes/admin.sessions";
import { adminUsersRouter } from "./routes/admin.users";
import { sessionsRouter } from "./routes/sessions";
import { leaderboardRouter } from "./routes/leaderboard";
import { createSocketServer } from "./sockets";

const app = express();
const server = createServer(app);

app.use(
  cors({
    origin(origin, callback) {
      const allowed = env.CORS_ORIGIN.split(",").map((value) => value.trim()).filter(Boolean);
      if (!origin) {
        callback(null, true);
        return;
      }
      if (allowed.includes("*") || allowed.includes(origin)) {
        callback(null, true);
        return;
      }
      if (env.AUTH_DEV_BYPASS && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error(`CORS blocked for origin ${origin}`));
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({
    ok: true,
    service: "devfest-quiz-api",
    leaderboardStore: isMemoryLeaderboard() ? "memory" : "redis",
  });
});

app.use("/api/auth", authRouter);
app.use("/api/admin/events", adminEventsRouter);
app.use("/api/admin/sessions", adminSessionsRouter);
app.use("/api/admin/users", adminUsersRouter);
app.use("/api/sessions", sessionsRouter);
app.use("/api", leaderboardRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

getFirebaseAdmin();
createSocketServer(server);

async function boot() {
  await initLeaderboardStore();
  await rebuildMissingLeaderboards();
  server.listen(env.PORT, () => {
    console.log(`API listening on http://localhost:${env.PORT}`);
    if (env.AUTH_DEV_BYPASS) {
      console.log("AUTH_DEV_BYPASS is enabled (local only)");
    }
  });
}

boot().catch((error) => {
  console.error("Failed to start API", error);
  process.exit(1);
});
