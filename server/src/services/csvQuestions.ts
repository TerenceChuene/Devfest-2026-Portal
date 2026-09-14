import { z } from "zod";
import { generatedQuestionsSchema, type GeneratedQuestions } from "./aiParsing";

/**
 * CSV columns: prompt,option1,option2,option3,option4,correctIndex
 * correctIndex is 1-based (1 = option1).
 * option3/option4 may be empty.
 */
export function parseQuestionsCsv(csvText: string): GeneratedQuestions["questions"] {
  const lines = csvText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  if (lines.length === 0) {
    throw new Error("CSV is empty");
  }

  const header = splitCsvLine(lines[0]!).map((h) => h.toLowerCase());
  const hasHeader =
    header.includes("prompt") &&
    header.includes("option1") &&
    header.includes("correctindex");

  const rows = hasHeader ? lines.slice(1) : lines;
  const questions: GeneratedQuestions["questions"] = [];

  for (const row of rows) {
    const cols = splitCsvLine(row);
    if (cols.length < 4) {
      throw new Error(`Invalid CSV row (need prompt,option1,option2,...,correctIndex): ${row}`);
    }

    const prompt = cols[0]!;
    const optionLabels = cols.slice(1, 5).filter((label) => label.trim().length > 0);
    const correctRaw = cols[5] ?? cols[optionLabels.length + 1] ?? cols[cols.length - 1]!;
    const correctIndex = Number.parseInt(correctRaw, 10);

    if (!prompt.trim()) throw new Error("Prompt cannot be empty");
    if (optionLabels.length < 2) throw new Error(`Row needs at least 2 options: ${prompt}`);
    if (!Number.isFinite(correctIndex) || correctIndex < 1 || correctIndex > optionLabels.length) {
      throw new Error(`correctIndex out of range for: ${prompt}`);
    }

    questions.push({
      prompt: prompt.trim(),
      options: optionLabels.map((label, index) => ({
        label: label.trim(),
        isCorrect: index + 1 === correctIndex,
      })),
    });
  }

  const validated = generatedQuestionsSchema.safeParse({ questions });
  if (!validated.success) {
    throw new Error(JSON.stringify(validated.error.flatten()));
  }
  return validated.data.questions;
}

function splitCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i]!;
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch === "," && !inQuotes) {
      result.push(current);
      current = "";
      continue;
    }
    current += ch;
  }
  result.push(current);
  return result;
}

export const saveQuestionsBodySchema = z.object({
  questions: generatedQuestionsSchema.shape.questions,
  replace: z.boolean().optional().default(true),
});
