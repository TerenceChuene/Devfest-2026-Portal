# DevFest Live Quiz — Build & Implementation Plan

A live quiz app for conference sessions: attendees scan a QR code (or type a short pin), sign in with Google, race through a **self-paced** quiz, and watch a **live leaderboard on their phone** (including their own rank). Admins get a rankings view for the room. This doc is written to be fed into Cursor phase by phase — each phase ends with a ready-to-paste prompt.

---

## 0. Locked Decisions

| Area | Decision | Why |
|---|---|---|
| Primary DB | **PostgreSQL** (not Firestore) | Sessions/questions/answers/leaderboards are relational; joins and aggregates (event leaderboard, per-speaker stats) matter. |
| Frontend hosting | Firebase Hosting (static Flutter web build) | Pairs with Firebase Auth; free, fast CDN. |
| Backend hosting | Render or Fly.io (persistent Node process) | Socket.io needs a long-lived process — rules out pure serverless for the WS server. |
| Redis hosting | Upstash or Redis Cloud free tier | Sorted sets for live scoring; no infra to manage. |
| Repo shape | Monorepo: `client/` (Flutter web) + `server/` (Node/Express + Socket.io) | Matches the existing scaffold; skip cross-language workspaces. |
| LLM for question generation | Gemini via `@google/generative-ai`, server-side only | Keeps the API key off the client; validate/sanitize before DB write. |
| Scope of "web app" | Flutter **web** only for v1 | No app-store download; native targets can come later. |
| **Tenancy** | **Multi-event, single-tenant** | One platform instance; many events (DevFest, Cloud Summit, Build with AI) created in admin. Not multi-org SaaS. |
| **Global leaderboard** | **Event-scoped** (resets per event) | Everyone starts at zero for that day's grand prize; no all-time rolling advantage for regulars. |
| **Admin bootstrap** | Manual Postgres role flip + Firebase custom claims | No super-admin UI for v1. Login → flip `users.role` → mint claim via script. Admins can later promote others in-app. |
| **Join** | QR **and** 4-character alphanumeric pin (`/join` + code like `A4X9`) | **Anyone with the pin can join** while the session is `join_open` — no allowlist, ticket, invite, or time window. Pin (or QR) is the only attendee gate. |
| **Attempts** | **One attempt per user per session** | First successful join creates the only playthrough. Disconnect / refresh → **resume**. After `completed_at` → **"Already played"** — no retake. Mid-quiz abandon = same attempt (resume only, never reset). |
| **Session open duration** | **Open until admin closes** | No timed join window. Session stays `join_open` indefinitely until admin sets `closed`. |
| **Quiz pacing** | **Autonomous / self-paced** | Each joiner starts at Q1 on their own clock. Admin close blocks **new** joins only — **never kicks in-progress players**, who may finish after close. |
| **Leaderboard (attendee)** | **In-app, live** — top ranks **plus personal rank** | Attendees see where they stand during/after the quiz on their own device. More useful than a room projector for self-paced play. |
| **Leaderboard (admin)** | **Admin rankings view** | Organizers see full/session rankings (and event board) without needing a projector mode. |
| **Projector / Ghost board** | **Out of scope for v1** | Deferred; phone + admin boards cover the need. |
| **Stack** | Postgres + Redis + Firebase Auth (Google) + Gemini + Flutter Web | Locked for production v1. |

---

## 1. Data Model

### 1.1 Entity overview

- `events` — top-level container (DevFest 2026, Cloud Summit, …). Event-scoped leaderboard lives here.
- `users` — attendees and admins, keyed by Firebase UID. `role` mirrors Firebase custom claim `admin`.
- `sessions` — one per talk/quiz; belongs to an event; has QR + 4-char `session_code`.
- `questions` / `question_options` — ordered MCQs for a session.
- `session_participants` — who joined, their per-user progress (`current_order_index`), and durable score.
- `quiz_answers` — one row per (user, question); stores response time and points.

### 1.2 Session lifecycle (autonomous)

```
draft  →  join_open  →  closed
              │              │
              │              └─ Admin close only (no timed join window)
              │
              ├─ Valid pin + not yet a participant → join → Q1 on personal timer (one attempt starts)
              ├─ Already participant, in progress → resume (same attempt)
              ├─ Already participant, completed   → "Already played" (no second attempt)
              └─ Session closed + never joined    → "Quiz Closed"
```

**Product rules (join / attempts)**
1. **Pin + open session.** Anyone signed in with a valid pin may join for as long as `status = join_open`. No timed window, allowlist, or cut-off clock.
2. **One attempt per session.** `session_participants` PK `(session_id, user_id)` is created once — that row *is* the attempt. Reconnect → resume. Never delete/reset for a retake in v1. Completed → **"Already played"**.
3. **Admin close only.** New joins stop when admin sets `closed`. In-progress players keep their attempt and finish on their own clock.

- Admin opens via `open-join` (sets `opened_at`); closes via `close` (sets `closed_at`). Session stays open until that close.
- There is **no** global `current_question_id`. Each participant advances independently.
- Attendees and admins subscribe to session (and optionally event) rooms for live `leaderboard_update` events.

### 1.3 PostgreSQL DDL (starting schema — generate real migrations from this)

```sql
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

create table events (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  slug text unique not null,                  -- URL-friendly: "devfest-2026"
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table users (
  id uuid primary key default uuid_generate_v4(),
  firebase_uid text unique not null,
  email text not null,
  display_name text,
  avatar_url text,
  role text not null default 'attendee' check (role in ('attendee', 'admin')),
  created_at timestamptz not null default now()
);

create table sessions (
  id uuid primary key default uuid_generate_v4(),
  event_id uuid not null references events(id) on delete cascade,
  title text not null,
  speaker_name text,
  session_code text unique not null,          -- 4-char alphanumeric, e.g. A4X9
  status text not null default 'draft'
    check (status in ('draft', 'join_open', 'closed')),
  opened_at timestamptz,                      -- set when admin opens (no auto-close)
  closed_at timestamptz,                      -- set when admin closes
  question_time_limit_seconds int not null default 15,
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

create table questions (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid not null references sessions(id) on delete cascade,
  prompt text not null,
  order_index int not null,
  time_limit_seconds int,                     -- overrides session default if set
  created_at timestamptz not null default now(),
  unique (session_id, order_index)
);

create table question_options (
  id uuid primary key default uuid_generate_v4(),
  question_id uuid not null references questions(id) on delete cascade,
  label text not null,
  is_correct boolean not null default false,
  order_index int not null
);

create table session_participants (
  session_id uuid not null references sessions(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  current_order_index int not null default 0, -- next question to answer (0-based)
  quiz_started_at timestamptz,                -- when they received/started Q1
  completed_at timestamptz,                   -- set when last question answered
  total_score int not null default 0,
  primary key (session_id, user_id)
);

-- Per-user question start times (server-authoritative scoring clock)
create table participant_question_timers (
  session_id uuid not null references sessions(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  question_id uuid not null references questions(id) on delete cascade,
  started_at timestamptz not null default now(),
  primary key (user_id, question_id)
);

create table quiz_answers (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid not null references sessions(id) on delete cascade,
  question_id uuid not null references questions(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  option_id uuid references question_options(id),
  is_correct boolean not null,
  response_ms int not null,
  points_awarded int not null,
  answered_at timestamptz not null default now(),
  unique (question_id, user_id)
);

create index idx_sessions_event on sessions(event_id);
create index idx_quiz_answers_session on quiz_answers(session_id);
create index idx_session_participants_score on session_participants(session_id, total_score desc);
```

> Redis holds the **live** leaderboard (see §4). Postgres `session_participants.total_score` + `quiz_answers` are durable truth; rebuild Redis from Postgres if needed.

### 1.4 Session code format

- Exactly **4 characters**, uppercase alphanumeric, excluding ambiguous glyphs (`0/O`, `1/I/L`).
- Alphabet suggestion: `23456789ABCDEFGHJKMNPQRSTUVWXYZ`.
- Generated uniquely on session create; embedded in QR as `{WEB_ORIGIN}/join?code=A4X9` and typed on `/join`.

---

## 2. API Contract

### 2.1 REST endpoints (Node/Express)

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /api/auth/session` | Firebase ID token | Verify token, upsert `users`, return short-lived backend JWT. Sync `role` from Postgres (and expect Firebase custom claim `admin` for admins). |
| `POST /api/admin/events` | Admin | Create an event. |
| `GET /api/admin/events` | Admin | List events. |
| `PATCH /api/admin/events/:id` | Admin | Update event metadata. |
| `POST /api/admin/sessions` | Admin | Create session under an `eventId`; returns `session_code` + join URL + QR payload. |
| `GET /api/admin/sessions` | Admin | List sessions (filter by `eventId`). |
| `GET /api/admin/sessions/:id` | Admin | Session detail incl. questions + open/closed status. |
| `PATCH /api/admin/sessions/:id` | Admin | Update title, per-question time limits, etc. |
| `DELETE /api/admin/sessions/:id` | Admin | Remove a session. |
| `POST /api/admin/sessions/:id/questions` | Admin | Bulk-insert / save reviewed questions. |
| `POST /api/admin/sessions/:id/questions/generate` | Admin | AI parse speaker notes → review JSON (does not auto-save). |
| `POST /api/admin/sessions/:id/open-join` | Admin | Flip to `join_open`; set `opened_at`. Stays open until admin closes. |
| `POST /api/admin/sessions/:id/close` | Admin | Set `closed` + `closed_at`. Blocks new joins only. |
| `POST /api/admin/users/:id/grant-admin` | Admin | Promote another user: set Postgres `role=admin` + set Firebase custom claim. |
| `GET /api/sessions/by-code/:code` | Attendee | Resolve pin/QR code → session metadata + whether join is open. |
| `POST /api/sessions/:id/join` | Attendee | If already a participant → resume (or 409 `"Already played"` if `completed_at` set). Else if joins open → create participant (one attempt) + return Q1 + `serverStartTime`. Else 403 `"Quiz Closed"`. Pin resolved via `by-code` before this call. |
| `POST /api/sessions/:id/answer` | Attendee | Submit answer for current question (REST or WS — see §2.3). Prefer WS for live path; REST allowed as fallback. |
| `GET /api/sessions/:id/me` | Attendee | Resume state: current question, remaining time, score. |
| `GET /api/events/:eventId/leaderboard` | Authed | Event-scoped aggregate leaderboard. Response includes `top` and, for the caller, `me: { rank, score, displayName }` even if outside top-N. |
| `GET /api/sessions/:id/leaderboard` | Authed | Session board: `top` + caller `me` rank/score. Attendees use this on phone; admins use the same data in admin rankings UI (admin may request a higher `limit`). |

### 2.2 AI document parsing endpoint — contract detail

`POST /api/admin/sessions/:id/questions/generate`

Request:
```json
{ "sourceText": "raw speaker notes or transcript..." }
```

Response (strict schema — validate with Zod before DB write):
```json
{
  "questions": [
    {
      "prompt": "What is the primary benefit of circuit breakers in microservices?",
      "options": [
        { "label": "Prevent cascading failures", "isCorrect": true },
        { "label": "Reduce code duplication", "isCorrect": false },
        { "label": "Speed up deployments", "isCorrect": false },
        { "label": "Encrypt network traffic", "isCorrect": false }
      ]
    }
  ]
}
```

Implementation notes:
- Gemini system prompt: **JSON only**, no prose, no markdown fences.
- Validate with Zod; on failure retry once with the validation error appended; then fail loudly (422 + raw output for debug).
- Returns parsed JSON for **admin review** — does not auto-save. Save hits `POST .../questions`.

### 2.3 WebSocket event contract (Socket.io)

Rooms:
- `session:{sessionId}` — participants + projector
- `event:{eventId}` — optional for event-wide leaderboard screens

**Client → server**

| Event | Payload | Notes |
|---|---|---|
| `join_session` | `{ sessionId }` | Auth via socket handshake JWT. Same rules as REST join: open + first time → create attempt + Q1; in progress → resume; completed → `already_played`; closed + never joined → `quiz_closed`. |
| `subscribe_leaderboard` | `{ sessionId }` or `{ eventId }` | Attendee or admin: receive live board updates (no need to be mid-quiz). |
| `submit_answer` | `{ sessionId, questionId, optionId }` | Server scores from `participant_question_timers.started_at`. Never trust client elapsed time. On success, advances participant and may include next question in the ack / follow-up event. |

**Server → client**

| Event | Payload | Notes |
|---|---|---|
| `session_state` | `{ status, participantCount, myProgress? }` | On join / resume. |
| `question_ready` | `{ questionId, prompt, options, timeLimitSeconds, serverStartTime, orderIndex, totalQuestions }` | Sent **to that user only** when their next question starts (not broadcast). |
| `answer_result` | `{ questionId, isCorrect, pointsAwarded, correctOptionId, completed }` | Private. If `completed`, quiz finished for this user. |
| `quiz_closed` | `{ reason }` | New join rejected because session is `closed`. |
| `already_played` | `{ sessionId }` | User already completed their one attempt. |
| `session_opened` | `{ openedAt }` | Broadcast when admin opens joins. |
| `session_closed` | `{ closedAt }` | Broadcast when admin closes. |
| `leaderboard_update` | `{ sessionId, top: [{ userId, displayName, score, rank }], participantCount }` | Debounced ≤500ms. Clients that need "my rank" combine with REST `me` or a private `my_rank` field when the socket user is a participant. |
| `event_leaderboard_update` | `{ eventId, top: [...] }` | Debounced; event-scoped grand prize board. |

---

## 3. Scoring Algorithm

Max 1000 points for a correct answer submitted instantly; decays linearly to a floor as the **personal** time limit approaches. Wrong answers score 0.

```
BASE_POINTS = 1000
MIN_POINTS  = 200
TIME_LIMIT_MS = question.timeLimitSeconds * 1000

function scoreAnswer(isCorrect, responseMs):
  if not isCorrect:
    return 0
  clamped = min(responseMs, TIME_LIMIT_MS)
  decayFactor = clamped / TIME_LIMIT_MS
  points = BASE_POINTS - (BASE_POINTS - MIN_POINTS) * decayFactor
  return round(points)
```

`responseMs` = `answer_received_at - participant_question_timers.started_at` (both server timestamps). Late answers after the personal limit → 0 points (no error dialog).

---

## 4. Real-Time Leaderboard Design (Attendee + Admin)

- On each scored answer:
  - `ZINCRBY leaderboard:session:{sessionId} {points} {userId}`
  - `ZINCRBY leaderboard:event:{eventId} {points} {userId}`
- Reads: `ZREVRANGE ... 0 9 WITHSCORES` for top-10; `ZREVRANK` + `ZSCORE` for the caller's **personal rank** (1-based).
- **Trailing debounce 500ms** per session (and separately per event): schedule at most one emit; when it fires, read current top-N and emit `leaderboard_update` once.
- On participant completion / session close, reconcile Redis → `session_participants.total_score`.
- On backend startup, rebuild missing Redis keys from Postgres.

**Attendee UX (v1):** during the quiz (and after finishing), a leaderboard screen/sheet shows top scorers **and a pinned "You — rank #N · score S"** row so players outside the top-10 still know where they stand. Reachable from the quiz flow without leaving the session.

**Admin UX (v1):** session rankings page (larger list, live updates) + event grand-prize rankings. Same APIs; admin UI may request a higher `limit` (e.g. top 50).

**Not in v1:** fullscreen projector / Ghost Leaderboard route.

---

## 5. Repo Structure

```
devfest2026_portal/
├── client/                     # Flutter web app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── join/           # /join + pin entry + QR deep link
│   │   │   ├── quiz/           # self-paced question UI + timer
│   │   │   ├── leaderboard/    # attendee board (top + my rank) + admin rankings
│   │   │   └── admin/          # events, sessions, AI review, grant-admin, rankings
│   │   ├── services/
│   │   │   ├── socket_service.dart
│   │   │   ├── api_client.dart
│   │   │   └── auth_service.dart
│   │   └── shared/
│   └── pubspec.yaml
├── server/                     # Node/Express + Socket.io
│   ├── src/
│   │   ├── index.ts
│   │   ├── routes/
│   │   ├── sockets/
│   │   ├── services/
│   │   │   ├── scoring.ts
│   │   │   ├── leaderboard.ts
│   │   │   ├── aiParsing.ts
│   │   │   └── sessionCodes.ts
│   │   ├── scripts/
│   │   │   └── mintAdminClaim.ts   # bootstrap: set Firebase claim + confirm Postgres role
│   │   ├── db/
│   │   └── middleware/
│   └── package.json
├── docs/
│   └── Build_Plan.md
├── docker-compose.yml          # local Postgres + Redis
└── README.md
```

---

## 6. Environment Variables

```
# server/.env
DATABASE_URL=postgres://...
REDIS_URL=rediss://...
FIREBASE_PROJECT_ID=...
FIREBASE_ADMIN_SDK_JSON=...        # service account, server-side only
GEMINI_API_KEY=...
PORT=4000
CORS_ORIGIN=https://your-web-app-domain
WEB_ORIGIN=https://your-web-app-domain   # used when minting join URLs / QR payloads
JWT_SECRET=...

# client (Flutter — --dart-define or firebase_options.dart)
API_BASE_URL=https://your-api-domain
FIREBASE_API_KEY=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_APP_ID=...
```

---

## 7. Admin Bootstrap (ops, not product UI)

1. Sign in once with Google → `users` row created as `attendee`.
2. Manually: `UPDATE users SET role = 'admin' WHERE email = 'you@example.com';`
3. Run `server` script `mintAdminClaim.ts --email you@example.com` → sets Firebase custom claim `{ admin: true }`.
4. Sign out / sign in so the ID token picks up the claim.
5. Later: use `POST /api/admin/users/:id/grant-admin` to promote other organizers (updates Postgres + claim).

---

## 8. Phased Execution Plan

Each phase is one Cursor session. Don't start the next until acceptance criteria pass.

### Phase 1 — Core Infrastructure, Events & Auth

**Tasks**
1. Scaffold `client/` + `server/` per §5 (TypeScript on server if not already).
2. `docker-compose.yml` for Postgres + Redis; run schema §1.3.
3. Flutter web: Firebase Google Sign-In → `POST /api/auth/session` → store backend JWT in memory.
4. Admin middleware: require Postgres `role=admin` **and** Firebase claim `admin` (or claim alone after sync — pick one source of truth: **Postgres role authoritative for API**; claim used as fast client gate).
5. Seed script + `mintAdminClaim.ts`.
6. Minimal admin: create/list **events** only (sessions come in Phase 3).

**Acceptance criteria**
- `docker-compose up` brings up Postgres + Redis.
- Google sign-in lands on "signed in as {email}".
- After manual role flip + claim script, admin routes succeed; attendees get 403.

**Cursor prompt**
```
Using docs/Build_Plan.md (sections 0, 1.3, 5, 6, 7), scaffold infra + auth:
- server: Express + TypeScript, Postgres (Prisma or pg + migrations), schema from §1.3,
  POST /api/auth/session (Firebase Admin verify → upsert users → JWT), requireAdmin
  middleware (Postgres role), scripts/mintAdminClaim.ts, POST/GET /api/admin/events.
- client: Flutter web, Firebase Google Sign-In, exchange ID token for JWT, simple
  signed-in shell + placeholder admin events list gated on role.
- docker-compose.yml for Postgres + Redis.
Do not build quiz, join, or projector UI yet.
```

---

### Phase 2 — Autonomous Quiz Engine

**Tasks**
1. Socket.io rooms; implement §2.3 join / `question_ready` / `submit_answer` / `answer_result`.
2. Scoring §3 using `participant_question_timers`.
3. Open/close enforcement: join allowed only while `join_open`; one attempt; reject new joins when `closed` with `quiz_closed`; completed → `already_played`.
4. Flutter: `/join` pin entry + deep link; self-paced quiz UI with timer synced to `serverStartTime`; lock on submit; "Quiz Closed" / "Already played" screens.
5. Internal admin/test route to open a seeded session with 2–3 questions (full admin UI in Phase 3).

**Acceptance criteria**
- Two tabs can join while open and progress at different speeds on their own timers.
- After admin close → new users "Quiz Closed"; in-progress users still finish.
- Completed user cannot start a second attempt.
- Mid-quiz refresh resumes correct question + remaining time via `GET /me` or socket resume.
- Post-limit answers score 0; duplicate answers rejected cleanly.

**Cursor prompt**
```
Using docs/Build_Plan.md sections 1.2, 2.3, and 3, build the autonomous quiz engine.
Backend: Socket.io join_session / submit_answer with per-user timers; open-join /
close with no timed window; one attempt per user; scoring exactly as §3; resume via
session_state + question_ready. Frontend: /join (4-char pin), self-paced quiz UI,
Quiz Closed / Already played states. Seed a test session for two-tab verification.
No projector yet.
```

---

### Phase 3 — Content Ingestion & Admin Portal

**Tasks**
1. Full session CRUD under events; 4-char code generation (§1.4); QR payload = `{WEB_ORIGIN}/join?code=XXXX`.
2. Gemini generate + Zod validate + review UI; CSV bulk upload.
3. Open-join / close controls (no timed window); grant-admin UI for organizers.
4. Admin session detail shows live participant count while open.

**Acceptance criteria**
- Create event → create session → generate/review/save questions → open join → QR + pin work.
- Non-admins 403 on admin routes.

**Cursor prompt**
```
Using docs/Build_Plan.md sections 2.1, 2.2, 1.4, build admin portal + ingestion:
session CRUD under events, Gemini generate-with-review, CSV upload, QR + pin,
open-join/close, grant-admin. Wire client admin routes to these APIs.
```

---

### Phase 4 — Live Leaderboards (Attendee + Admin) & Polish

**Tasks**
1. Redis session + **event** sorted sets; 500ms trailing debounce (§4); `ZREVRANK` for personal rank.
2. Attendee session leaderboard UI: top-N + pinned "You" row; event grand-prize board.
3. Admin rankings views (session + event) with live updates and higher list limit.
4. Reconcile on completion/close; rebuild on startup.
5. Load-test burst answers; confirm ≤ ~2 `leaderboard_update`s/sec/session.
6. Light polish: question transitions; post-quiz “your rank” moment.

**Acceptance criteria**
- Attendee sees live top list and their own rank even when outside top-10.
- Admin rankings update as self-paced answers land without flooding the wire.
- Event leaderboard sums only that event's sessions.
- Redis flush → rebuild from Postgres restores boards.

**Cursor prompt**
```
Using docs/Build_Plan.md section 4, implement Redis leaderboards (session + event),
debounce broadcaster, attendee board with personal rank (top + me), admin rankings
UI, reconcile/rebuild, and a small load-test script for submit_answer bursts.
No projector/display route in v1.
```

---

## 9. Testing & QA Checklist

- [ ] Auth: sign-in, sign-out, expired token; admin claim + role required for admin APIs.
- [ ] Multi-event: two events' leaderboards never mix scores.
- [ ] Join: QR and 4-char pin both resolve; wrong pin shows a clear error.
- [ ] Join: valid pin while `join_open` starts the one attempt at Q1; session stays open until admin closes (no auto time limit); after close → new users "Quiz Closed"; in-progress finish; completed user → "Already played"; reconnect mid-quiz resumes same attempt.
- [ ] Self-paced: two users on different questions; timers independent and server-anchored.
- [ ] Scoring: post-limit → 0; duplicate answer → clean error; no client-trusted elapsed time.
- [ ] Reconnect: resume mid-quiz with correct remaining time.
- [ ] AI parsing: off-schema Gemini output never auto-saved.
- [ ] Attendee leaderboard: shows top-N and caller's own rank/score while in session and after finish.
- [ ] Admin rankings: session + event lists update live; higher limit than attendee top-N.
- [ ] Leaderboard: session totals match sum of `quiz_answers.points_awarded`; event board = sum across that event's sessions.
- [ ] Load: debounce holds under burst traffic.

---

## 10. Deployment Checklist

1. Provision Postgres, Redis, Firebase (Google provider on).
2. Deploy `server` as a persistent service; set §6 env vars.
3. `flutter build web` → Firebase Hosting.
4. Set `CORS_ORIGIN` + `WEB_ORIGIN`.
5. Bootstrap first admin (§7) before the event.
6. Pre-generate / print session QR cards; don't rely on live generation only.
7. Dry run 5–10 devices on venue WiFi; confirm attendee boards stay usable under load.

---

## 11. Risks & Notes

- **Conference WiFi** remains the likeliest failure point — test on-site.
- **Pin + one attempt, no join timer:** access is “knows the pin + session still `join_open` + never played.” Admin close must not kick in-progress players; completed users must not get a retake even while the session is still open.
- **Attempt identity:** treat Google account (`users` / Firebase UID) as the attempt identity — same person on a second device still hits the same `(session_id, user_id)` row.
- **Self-paced board optics:** early joiners may sit high on the board first — attendee "You" rank still keeps later joiners engaged. Optional: show "in progress" count (nice-to-have, not required for v1).
- **Projector deferred:** if a room screen is needed later, reuse the same leaderboard APIs in a fullscreen admin/kiosk route — do not block v1 on it.
- **Gemini drift:** always human-review before save.
- **Single-tenant multi-event:** admins are global to the instance (any event). If you later need per-event organizers, add `event_admins` — out of scope for v1.
)
