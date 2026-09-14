import { describe, expect, it } from "node:test";
import assert from "node:assert/strict";
import { scoreAnswer, BASE_POINTS, MIN_POINTS } from "./scoring";

describe("scoreAnswer", () => {
  it("returns 0 for incorrect answers", () => {
    assert.equal(scoreAnswer(false, 0, 15), 0);
  });

  it("returns BASE_POINTS for instant correct answers", () => {
    assert.equal(scoreAnswer(true, 0, 15), BASE_POINTS);
  });

  it("returns MIN_POINTS at the time limit", () => {
    assert.equal(scoreAnswer(true, 15_000, 15), MIN_POINTS);
  });

  it("returns 0 after the time limit", () => {
    assert.equal(scoreAnswer(true, 15_001, 15), 0);
  });

  it("decays linearly mid-window", () => {
    assert.equal(scoreAnswer(true, 7_500, 15), 600);
  });
});
