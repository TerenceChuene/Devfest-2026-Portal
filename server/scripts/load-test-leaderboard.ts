/**
 * Prove trailing 500ms debounce under a burst of score updates.
 *
 * Usage:
 *   npx tsx scripts/load-test-leaderboard.ts --session <uuid> --event <uuid> --n 50
 */
import { EventEmitter } from "node:events";
import {
  addScore,
  initLeaderboardStore,
  getSessionLeaderboard,
} from "../src/services/leaderboard";
import { setSocketServer } from "../src/sockets/registry";

function arg(flag: string, fallback?: string) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return fallback;
  return process.argv[idx + 1] ?? fallback;
}

async function main() {
  const sessionId = arg("--session", "00000000-0000-4000-8000-000000000001")!;
  const eventId = arg("--event", "00000000-0000-4000-8000-000000000002")!;
  const n = Number(arg("--n", "50"));

  await initLeaderboardStore();

  let updates = 0;
  const startedAt = Date.now();
  const fakeIo = {
    to() {
      return {
        emit(event: string) {
          if (event === "leaderboard_update") {
            updates += 1;
            console.log(`leaderboard_update #${updates} at +${Date.now() - startedAt}ms`);
          }
        },
      };
    },
  };
  setSocketServer(fakeIo as never);

  console.log(`Bursting ${n} score increments…`);
  await Promise.all(
    Array.from({ length: n }, (_, i) =>
      addScore({
        sessionId,
        eventId,
        userId: `00000000-0000-4000-8000-${String(i % 10).padStart(12, "0")}`,
        points: 10,
      }),
    ),
  );

  await new Promise((resolve) => setTimeout(resolve, 1500));
  const board = await getSessionLeaderboard({ sessionId, limit: 10 });
  const elapsedSec = (Date.now() - startedAt) / 1000;
  console.log(`leaderboard_update count=${updates} over ${elapsedSec.toFixed(2)}s`);
  console.log(`top entries=${board.top.length}`);
  if (updates < 1 || updates > 3) {
    console.error("FAIL: expected ~1 leaderboard_update for a single burst (trailing 500ms debounce)");
    process.exit(1);
  }
  console.log("PASS: debounce held under burst");
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

void EventEmitter;
