import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { parseQuestionsCsv } from "./csvQuestions";

describe("parseQuestionsCsv", () => {
  it("parses headered CSV with optional empty options", () => {
    const csv = [
      "prompt,option1,option2,option3,option4,correctIndex",
      "What is 2+2?,3,4,5,,2",
      '"Quoted, prompt",A,B,C,D,1',
    ].join("\n");

    const questions = parseQuestionsCsv(csv);
    assert.equal(questions.length, 2);
    assert.equal(questions[0]!.options.length, 3);
    assert.equal(questions[0]!.options[1]!.isCorrect, true);
    assert.equal(questions[1]!.prompt, "Quoted, prompt");
    assert.equal(questions[1]!.options[0]!.isCorrect, true);
  });
});
