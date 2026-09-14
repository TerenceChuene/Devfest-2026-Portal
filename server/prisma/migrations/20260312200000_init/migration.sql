-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('attendee', 'admin');

-- CreateEnum
CREATE TYPE "SessionStatus" AS ENUM ('draft', 'join_open', 'closed');

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "starts_at" TIMESTAMPTZ(6),
    "ends_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "firebase_uid" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "display_name" TEXT,
    "avatar_url" TEXT,
    "role" "UserRole" NOT NULL DEFAULT 'attendee',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "speaker_name" TEXT,
    "session_code" TEXT NOT NULL,
    "status" "SessionStatus" NOT NULL DEFAULT 'draft',
    "opened_at" TIMESTAMPTZ(6),
    "closed_at" TIMESTAMPTZ(6),
    "question_time_limit_seconds" INTEGER NOT NULL DEFAULT 15,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "questions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_id" UUID NOT NULL,
    "prompt" TEXT NOT NULL,
    "order_index" INTEGER NOT NULL,
    "time_limit_seconds" INTEGER,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "question_options" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "question_id" UUID NOT NULL,
    "label" TEXT NOT NULL,
    "is_correct" BOOLEAN NOT NULL DEFAULT false,
    "order_index" INTEGER NOT NULL,

    CONSTRAINT "question_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_participants" (
    "session_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "current_order_index" INTEGER NOT NULL DEFAULT 0,
    "quiz_started_at" TIMESTAMPTZ(6),
    "completed_at" TIMESTAMPTZ(6),
    "total_score" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "session_participants_pkey" PRIMARY KEY ("session_id","user_id")
);

-- CreateTable
CREATE TABLE "participant_question_timers" (
    "session_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "question_id" UUID NOT NULL,
    "started_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "participant_question_timers_pkey" PRIMARY KEY ("user_id","question_id")
);

-- CreateTable
CREATE TABLE "quiz_answers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_id" UUID NOT NULL,
    "question_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "option_id" UUID,
    "is_correct" BOOLEAN NOT NULL,
    "response_ms" INTEGER NOT NULL,
    "points_awarded" INTEGER NOT NULL,
    "answered_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "quiz_answers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "events_slug_key" ON "events"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "users_firebase_uid_key" ON "users"("firebase_uid");

-- CreateIndex
CREATE UNIQUE INDEX "sessions_session_code_key" ON "sessions"("session_code");

-- CreateIndex
CREATE INDEX "idx_sessions_event" ON "sessions"("event_id");

-- CreateIndex
CREATE UNIQUE INDEX "questions_session_id_order_index_key" ON "questions"("session_id", "order_index");

-- CreateIndex
CREATE INDEX "idx_session_participants_score" ON "session_participants"("session_id", "total_score" DESC);

-- CreateIndex
CREATE INDEX "idx_quiz_answers_session" ON "quiz_answers"("session_id");

-- CreateIndex
CREATE UNIQUE INDEX "quiz_answers_question_id_user_id_key" ON "quiz_answers"("question_id", "user_id");

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sessions" ADD CONSTRAINT "sessions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "questions" ADD CONSTRAINT "questions_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "question_options" ADD CONSTRAINT "question_options_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_participants" ADD CONSTRAINT "session_participants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_participants" ADD CONSTRAINT "session_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "participant_question_timers" ADD CONSTRAINT "participant_question_timers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "participant_question_timers" ADD CONSTRAINT "participant_question_timers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "participant_question_timers" ADD CONSTRAINT "participant_question_timers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_answers" ADD CONSTRAINT "quiz_answers_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_answers" ADD CONSTRAINT "quiz_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_answers" ADD CONSTRAINT "quiz_answers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_answers" ADD CONSTRAINT "quiz_answers_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "question_options"("id") ON DELETE SET NULL ON UPDATE CASCADE;

