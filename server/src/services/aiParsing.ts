import { z } from "zod";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { env } from "../config";

export const generatedQuestionsSchema = z.object({
  questions: z
    .array(
      z.object({
        prompt: z.string().min(1),
        options: z
          .array(
            z.object({
              label: z.string().min(1),
              isCorrect: z.boolean(),
            }),
          )
          .min(2)
          .max(4)
          .refine((options) => options.filter((o) => o.isCorrect).length === 1, {
            message: "Exactly one option must be marked isCorrect",
          }),
      }),
    )
    .min(1),
});

export type GeneratedQuestions = z.infer<typeof generatedQuestionsSchema>;

const SYSTEM_PROMPT = `You convert speaker notes into multiple-choice quiz questions.
Return JSON only. No markdown fences, no commentary.
Schema:
{
  "questions": [
    {
      "prompt": "string",
      "options": [
        { "label": "string", "isCorrect": true|false }
      ]
    }
  ]
}
Rules:
- 2 to 4 options per question
- Exactly one isCorrect: true per question
- Prefer practical comprehension questions from the notes
- Generate between 3 and 10 questions when the source is long enough`;

function extractJson(raw: string): unknown {
  const trimmed = raw.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced?.[1]?.trim() ?? trimmed;
  return JSON.parse(candidate);
}

export async function generateQuestionsFromNotes(sourceText: string): Promise<{
  questions: GeneratedQuestions["questions"];
  rawModelOutput?: string;
}> {
  if (!env.GEMINI_API_KEY) {
    const error = new Error("GEMINI_API_KEY is not configured");
    (error as Error & { code: string }).code = "gemini_unconfigured";
    throw error;
  }

  const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({
    model: "gemini-2.0-flash",
    generationConfig: { temperature: 0.3, responseMimeType: "application/json" },
  });

  async function call(extra?: string) {
    const prompt = [
      SYSTEM_PROMPT,
      extra ? `Previous output failed validation:\n${extra}` : "",
      "Speaker notes:",
      sourceText,
    ]
      .filter(Boolean)
      .join("\n\n");

    const result = await model.generateContent(prompt);
    return result.response.text();
  }

  let raw = await call();
  let parsed: unknown;
  try {
    parsed = extractJson(raw);
  } catch {
    raw = await call(`Output was not valid JSON. Raw was:\n${raw}`);
    parsed = extractJson(raw);
  }

  let validated = generatedQuestionsSchema.safeParse(parsed);
  if (!validated.success) {
    raw = await call(JSON.stringify(validated.error.flatten()));
    try {
      parsed = extractJson(raw);
    } catch {
      const err = new Error("Gemini returned non-JSON after retry");
      (err as Error & { code: string; raw: string }).code = "gemini_invalid";
      (err as Error & { raw: string }).raw = raw;
      throw err;
    }
    validated = generatedQuestionsSchema.safeParse(parsed);
    if (!validated.success) {
      const err = new Error("Gemini output failed schema validation after retry");
      (err as Error & { code: string; raw: string; details: unknown }).code = "gemini_invalid";
      (err as Error & { raw: string }).raw = raw;
      (err as Error & { details: unknown }).details = validated.error.flatten();
      throw err;
    }
  }

  return { questions: validated.data.questions, rawModelOutput: raw };
}
