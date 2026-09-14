import Redis from "ioredis";
import { env } from "../config";
import { prisma } from "../db/client";
import { getSocketServer } from "../sockets/registry";

export type LeaderboardEntry = {
  userId: string;
  displayName: string;
  score: number;
  rank: number;
};

type RankedScore = { member: string; score: number };

class MemoryZSet {
  private scores = new Map<string, number>();

  incrby(member: string, increment: number): number {
    const next = (this.scores.get(member) ?? 0) + increment;
    this.scores.set(member, next);
    return next;
  }

  set(member: string, score: number) {
    this.scores.set(member, score);
  }

  delKey() {
    this.scores.clear();
  }

  revrange(start: number, stop: number): RankedScore[] {
    const ranked = [...this.scores.entries()]
      .map(([member, score]) => ({ member, score }))
      .sort((a, b) => b.score - a.score || a.member.localeCompare(b.member));
    const end = stop < 0 ? ranked.length : stop + 1;
    return ranked.slice(start, end);
  }

  revrank(member: string): number | null {
    const ranked = this.revrange(0, -1);
    const idx = ranked.findIndex((row) => row.member === member);
    return idx === -1 ? null : idx;
  }

  score(member: string): number | null {
    if (!this.scores.has(member)) return null;
    return this.scores.get(member) ?? null;
  }

  get size() {
    return this.scores.size;
  }
}

class MemoryStore {
  private keys = new Map<string, MemoryZSet>();

  private zset(key: string) {
    let set = this.keys.get(key);
    if (!set) {
      set = new MemoryZSet();
      this.keys.set(key, set);
    }
    return set;
  }

  async zincrby(key: string, increment: number, member: string) {
    return this.zset(key).incrby(member, increment);
  }

  async zadd(key: string, score: number, member: string) {
    this.zset(key).set(member, score);
  }

  async del(key: string) {
    this.keys.delete(key);
  }

  async exists(key: string) {
    return this.keys.has(key) && this.zset(key).size > 0 ? 1 : 0;
  }

  async zrevrangeWithScores(key: string, start: number, stop: number): Promise<RankedScore[]> {
    return this.zset(key).revrange(start, stop);
  }

  async zrevrank(key: string, member: string) {
    return this.zset(key).revrank(member);
  }

  async zscore(key: string, member: string) {
    return this.zset(key).score(member);
  }
}

type Store = {
  zincrby(key: string, increment: number, member: string): Promise<number>;
  zadd(key: string, score: number, member: string): Promise<unknown>;
  del(key: string): Promise<unknown>;
  exists(key: string): Promise<number>;
  zrevrangeWithScores(key: string, start: number, stop: number): Promise<RankedScore[]>;
  zrevrank(key: string, member: string): Promise<number | null>;
  zscore(key: string, member: string): Promise<number | null>;
};

let store: Store | null = null;
let usingMemory = false;
let redisClient: Redis | null = null;

const sessionDebounce = new Map<string, NodeJS.Timeout>();
const eventDebounce = new Map<string, NodeJS.Timeout>();

function sessionKey(sessionId: string) {
  return `leaderboard:session:${sessionId}`;
}

function eventKey(eventId: string) {
  return `leaderboard:event:${eventId}`;
}

function redisAdapter(client: Redis): Store {
  return {
    async zincrby(key, increment, member) {
      return Number(await client.zincrby(key, increment, member));
    },
    async zadd(key, score, member) {
      return client.zadd(key, score, member);
    },
    async del(key) {
      return client.del(key);
    },
    async exists(key) {
      return client.exists(key);
    },
    async zrevrangeWithScores(key, start, stop) {
      const raw = await client.zrevrange(key, start, stop, "WITHSCORES");
      const rows: RankedScore[] = [];
      for (let i = 0; i < raw.length; i += 2) {
        rows.push({ member: raw[i]!, score: Number(raw[i + 1]) });
      }
      return rows;
    },
    async zrevrank(key, member) {
      const rank = await client.zrevrank(key, member);
      return rank;
    },
    async zscore(key, member) {
      const score = await client.zscore(key, member);
      return score == null ? null : Number(score);
    },
  };
}

export async function initLeaderboardStore() {
  if (store) return store;

  try {
    const client = new Redis(env.REDIS_URL, {
      maxRetriesPerRequest: 1,
      connectTimeout: 1000,
      retryStrategy: () => null,
      lazyConnect: true,
      enableOfflineQueue: false,
      showFriendlyErrorStack: true,
    });
    client.on("error", () => {
      /* connection errors handled by init fallback */
    });
    await client.connect();
    await Promise.race([
      client.ping(),
      new Promise((_, reject) => setTimeout(() => reject(new Error("Redis ping timeout")), 1500)),
    ]);
    redisClient = client;
    store = redisAdapter(client);
    usingMemory = false;
    console.log(`Leaderboard store: Redis (${env.REDIS_URL})`);
  } catch (error) {
    if (redisClient) {
      try {
        redisClient.disconnect();
      } catch {
        /* ignore */
      }
      redisClient = null;
    }
    console.warn("Redis unavailable — using in-memory leaderboard store");
    store = new MemoryStore();
    usingMemory = true;
  }

  return store;
}

export function isMemoryLeaderboard() {
  return usingMemory;
}

async function getStore() {
  return store ?? initLeaderboardStore();
}

async function resolveDisplayNames(userIds: string[]) {
  if (userIds.length === 0) return new Map<string, string>();
  const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const validIds = userIds.filter((id) => uuidRe.test(id));
  const names = new Map<string, string>();
  for (const id of userIds) {
    if (!uuidRe.test(id)) names.set(id, id);
  }
  if (validIds.length === 0) return names;

  const users = await prisma.user.findMany({
    where: { id: { in: validIds } },
    select: { id: true, displayName: true, email: true },
  });
  for (const user of users) {
    names.set(user.id, user.displayName?.trim() || user.email.split("@")[0] || user.email);
  }
  return names;
}

async function toEntries(rows: RankedScore[], offset = 0): Promise<LeaderboardEntry[]> {
  const names = await resolveDisplayNames(rows.map((row) => row.member));
  return rows.map((row, index) => ({
    userId: row.member,
    displayName: names.get(row.member) ?? "Player",
    score: Math.round(row.score),
    rank: offset + index + 1,
  }));
}

export async function addScore(params: {
  sessionId: string;
  eventId: string;
  userId: string;
  points: number;
}) {
  if (params.points === 0) {
    scheduleSessionBroadcast(params.sessionId);
    scheduleEventBroadcast(params.eventId);
    return;
  }

  const s = await getStore();
  await s.zincrby(sessionKey(params.sessionId), params.points, params.userId);
  await s.zincrby(eventKey(params.eventId), params.points, params.userId);
  scheduleSessionBroadcast(params.sessionId);
  scheduleEventBroadcast(params.eventId);
}

export async function getSessionLeaderboard(params: {
  sessionId: string;
  userId?: string;
  limit?: number;
}) {
  const limit = Math.min(Math.max(params.limit ?? 10, 1), 100);
  const s = await getStore();
  const topRows = await s.zrevrangeWithScores(sessionKey(params.sessionId), 0, limit - 1);
  const top = await toEntries(topRows);
  const participantCount = await prisma.sessionParticipant.count({
    where: { sessionId: params.sessionId },
  });

  let me: LeaderboardEntry | null = null;
  if (params.userId) {
    const rank = await s.zrevrank(sessionKey(params.sessionId), params.userId);
    const score = await s.zscore(sessionKey(params.sessionId), params.userId);
    if (rank != null && score != null) {
      const names = await resolveDisplayNames([params.userId]);
      me = {
        userId: params.userId,
        displayName: names.get(params.userId) ?? "You",
        score: Math.round(score),
        rank: rank + 1,
      };
    } else {
      const participant = await prisma.sessionParticipant.findUnique({
        where: {
          sessionId_userId: { sessionId: params.sessionId, userId: params.userId },
        },
      });
      if (participant) {
        const names = await resolveDisplayNames([params.userId]);
        me = {
          userId: params.userId,
          displayName: names.get(params.userId) ?? "You",
          score: participant.totalScore,
          rank: top.length + 1,
        };
      }
    }
  }

  return { top, me, participantCount };
}

export async function getEventLeaderboard(params: {
  eventId: string;
  userId?: string;
  limit?: number;
}) {
  const limit = Math.min(Math.max(params.limit ?? 10, 1), 100);
  const s = await getStore();
  const topRows = await s.zrevrangeWithScores(eventKey(params.eventId), 0, limit - 1);
  const top = await toEntries(topRows);

  let me: LeaderboardEntry | null = null;
  if (params.userId) {
    const rank = await s.zrevrank(eventKey(params.eventId), params.userId);
    const score = await s.zscore(eventKey(params.eventId), params.userId);
    if (rank != null && score != null) {
      const names = await resolveDisplayNames([params.userId]);
      me = {
        userId: params.userId,
        displayName: names.get(params.userId) ?? "You",
        score: Math.round(score),
        rank: rank + 1,
      };
    }
  }

  return { top, me };
}

function scheduleSessionBroadcast(sessionId: string) {
  const existing = sessionDebounce.get(sessionId);
  if (existing) clearTimeout(existing);
  const timer = setTimeout(async () => {
    sessionDebounce.delete(sessionId);
    try {
      const board = await getSessionLeaderboard({ sessionId, limit: 10 });
      getSocketServer()?.to(`session:${sessionId}`).emit("leaderboard_update", {
        sessionId,
        top: board.top,
        participantCount: board.participantCount,
      });
    } catch (error) {
      console.error("session leaderboard broadcast failed", error);
    }
  }, 500);
  sessionDebounce.set(sessionId, timer);
}

function scheduleEventBroadcast(eventId: string) {
  const existing = eventDebounce.get(eventId);
  if (existing) clearTimeout(existing);
  const timer = setTimeout(async () => {
    eventDebounce.delete(eventId);
    try {
      const board = await getEventLeaderboard({ eventId, limit: 10 });
      getSocketServer()?.to(`event:${eventId}`).emit("event_leaderboard_update", {
        eventId,
        top: board.top,
      });
    } catch (error) {
      console.error("event leaderboard broadcast failed", error);
    }
  }, 500);
  eventDebounce.set(eventId, timer);
}

/** Flush Redis session scores into Postgres participant totals. */
export async function reconcileSessionScores(sessionId: string) {
  const s = await getStore();
  const rows = await s.zrevrangeWithScores(sessionKey(sessionId), 0, -1);
  await prisma.$transaction(
    rows.map((row) =>
      prisma.sessionParticipant.updateMany({
        where: { sessionId, userId: row.member },
        data: { totalScore: Math.round(row.score) },
      }),
    ),
  );
}

export async function rebuildMissingLeaderboards() {
  const s = await getStore();
  const sessions = await prisma.session.findMany({
    select: { id: true, eventId: true },
  });

  for (const session of sessions) {
    const key = sessionKey(session.id);
    if ((await s.exists(key)) === 1) continue;

    const participants = await prisma.sessionParticipant.findMany({
      where: { sessionId: session.id, totalScore: { gt: 0 } },
    });
    if (participants.length === 0) continue;

    for (const participant of participants) {
      await s.zadd(key, participant.totalScore, participant.userId);
    }
  }

  const events = await prisma.event.findMany({ select: { id: true } });
  for (const event of events) {
    const key = eventKey(event.id);
    if ((await s.exists(key)) === 1) continue;

    const totals = await prisma.sessionParticipant.groupBy({
      by: ["userId"],
      where: { session: { eventId: event.id } },
      _sum: { totalScore: true },
    });

    for (const row of totals) {
      const score = row._sum.totalScore ?? 0;
      if (score > 0) await s.zadd(key, score, row.userId);
    }
  }
}

export async function shutdownLeaderboardStore() {
  if (redisClient) {
    await redisClient.quit();
    redisClient = null;
  }
  store = null;
}
