import path from "node:path";
import dotenv from "dotenv";
import { z } from "zod";

dotenv.config({ path: path.resolve(__dirname, "../.env") });
dotenv.config();

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  PORT: z.coerce.number().default(4000),
  CORS_ORIGIN: z.string().default("http://localhost:5000"),
  WEB_ORIGIN: z.string().default("http://localhost:5000"),
  JWT_SECRET: z.string().min(8),
  JWT_EXPIRES_IN: z.string().default("12h"),
  FIREBASE_PROJECT_ID: z.string().optional().default(""),
  FIREBASE_ADMIN_SDK_JSON: z.string().optional().default(""),
  FIREBASE_ADMIN_SDK_PATH: z.string().optional().default(""),
  AUTH_DEV_BYPASS: z.string().optional().default(""),
  GEMINI_API_KEY: z.string().optional().default(""),
});

const parsed = envSchema.safeParse(process.env);
if (!parsed.success) {
  console.error("Invalid environment variables:", parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;
