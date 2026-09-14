export const BASE_POINTS = 1000;
export const MIN_POINTS = 200;

/**
 * Max 1000 for an instant correct answer; linear decay to MIN_POINTS at the time limit.
 * Wrong answers and answers after the personal time limit score 0.
 */
export function scoreAnswer(
  isCorrect: boolean,
  responseMs: number,
  timeLimitSeconds: number,
): number {
  if (!isCorrect) return 0;

  const timeLimitMs = timeLimitSeconds * 1000;
  if (timeLimitMs <= 0) return isCorrect ? BASE_POINTS : 0;

  if (responseMs > timeLimitMs) return 0;

  const clamped = Math.min(Math.max(responseMs, 0), timeLimitMs);
  const decayFactor = clamped / timeLimitMs;
  const points = BASE_POINTS - (BASE_POINTS - MIN_POINTS) * decayFactor;
  return Math.round(points);
}
