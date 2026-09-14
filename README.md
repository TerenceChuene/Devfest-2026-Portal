# DevFest 2026 Portal — Live Quiz

Self-paced live quiz for community events: Flutter web client + Express/Prisma API.

See [docs/Build_Plan.md](docs/Build_Plan.md) for the full product plan.

## Prerequisites

- Node 20+ (nvm recommended)
- Flutter 3.47+
- Postgres 16 (via `docker compose` **or** any local Postgres)
- Redis (Phase 4; optional for Phase 1)
- Docker: add yourself to the group if needed — `sudo usermod -aG docker $USER` then re-login

## Quick start (Phase 1)

### 1. Database

**Option A — Docker** (preferred once your user can access the Docker socket):

```bash
docker compose up -d
```

**Option B — Existing local Postgres** (what this machine used during scaffold):

```bash
# example using popuser on localhost:5432
createuser / createdb → role `devfest` / db `devfest_quiz`
# then set DATABASE_URL in server/.env
```

Default `server/.env.example` expects:

`postgresql://devfest:devfest@localhost:5432/devfest_quiz`
### 2. API

```bash
cd server
cp .env.example .env
npm install
npx prisma migrate deploy   # or: npx prisma migrate dev --name init
npm run dev
```

API: `http://localhost:4000` · Health: `GET /health`

**Local auth without Firebase:** `.env` includes `AUTH_DEV_BYPASS=dev-bypass-secret`. The Flutter app’s “Continue as attendee/admin (dev)” buttons use this.

**Promote an admin:**

```bash
# After the user has signed in once:
# psql: UPDATE users SET role = 'admin' WHERE email = 'admin@example.com';
npm run mint-admin -- --email admin@example.com
```

For pure local/dev users (`dev:…` Firebase UIDs), `mint-admin` updates Postgres only.

### 3. Flutter web

```bash
cd client
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:4000 \
  --dart-define=AUTH_DEV_BYPASS=dev-bypass-secret
```

### Google Sign-In (optional for Phase 1)

1. Create a Firebase project, enable Google Auth.
2. `dart pub global activate flutterfire_cli && flutterfire configure`
3. Or pass `--dart-define=FIREBASE_API_KEY=…` (and related defines in `lib/firebase_options.dart`).
4. Add your web OAuth client ID via `--dart-define=GOOGLE_CLIENT_ID=…` (also set in `web/index.html` meta tag).
5. Put the Firebase Admin service account JSON in `server/.env` as `FIREBASE_ADMIN_SDK_JSON` or `FIREBASE_ADMIN_SDK_PATH`.

Recommended local client run (includes Google client ID):

```bash
cd client
flutter run -d web-server --web-hostname=localhost --web-port=5000 \
  --dart-define-from-file=dart_defines.json
```

## Phase 1 status

- [x] docker-compose (Postgres + Redis)
- [x] Express + TypeScript + Prisma schema
- [x] `POST /api/auth/session`, `GET /api/auth/me`
- [x] Admin events CRUD (`GET/POST/PATCH /api/admin/events`)
- [x] `mint-admin` script
- [x] Flutter sign-in shell + admin events list

## Phase 2 status

- [x] Scoring service (server-authoritative timers)
- [x] Join by 4-char pin, one attempt, open until admin closes
- [x] REST: `by-code`, `join`, `answer`, `me`, `open-join`, `close`, `seed-demo`
- [x] Socket.io: `join_session`, `submit_answer`, `question_ready`, `answer_result`
- [x] Flutter: Join pin UI, self-paced quiz + synced countdown, Quiz Closed / Already played

### Phase 2 quick test

1. Sign in as admin (dev) → **Seed demo quiz session** (copies pin)
2. Sign in as attendee in another tab → **Join a quiz** → enter pin
3. Answer questions; after finish, re-join → Already played
4. Admin close (via API `POST /api/admin/sessions/:id/close`) → new joiners get Quiz Closed; in-progress players finish

```bash
# API seed
curl -X POST http://localhost:4000/api/admin/sessions/seed-demo \
  -H "Authorization: Bearer $ADMIN_JWT"
```

## Phase 3 status

- [x] Session CRUD under events + join URL / QR payload
- [x] Save questions, CSV upload parse, Gemini generate (needs `GEMINI_API_KEY`)
- [x] Open-join / close controls
- [x] Grant-admin (`/api/admin/users`)
- [x] Flutter admin: Events → Sessions → detail (QR, AI/CSV review, open/close), Users

## Phase 4 status

- [x] Redis leaderboards (session + event) with in-memory fallback if Redis is down
- [x] 500ms trailing debounce broadcasts (`leaderboard_update` / `event_leaderboard_update`)
- [x] REST: `GET /api/sessions/:id/leaderboard`, `GET /api/events/:eventId/leaderboard` (top + me)
- [x] Rebuild missing keys on startup; reconcile on completion/close
- [x] Attendee leaderboard in quiz + post-quiz rank; admin rankings on session/event screens
- [x] `npm run load-test:leaderboard` debounce burst check

```bash
cd server
npm run load-test:leaderboard -- --n 50
```
