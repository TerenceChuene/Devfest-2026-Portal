import { prisma } from "../db/client";

/** Ambiguous glyphs excluded: 0/O, 1/I/L */
const ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";

export function generateSessionCode(length = 4): string {
  let code = "";
  for (let i = 0; i < length; i += 1) {
    code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)]!;
  }
  return code;
}

export function normalizeSessionCode(code: string): string {
  return code.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

export async function allocateUniqueSessionCode(maxAttempts = 20): Promise<string> {
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    const code = generateSessionCode();
    const existing = await prisma.session.findUnique({ where: { sessionCode: code } });
    if (!existing) return code;
  }
  throw new Error("Unable to allocate a unique session code");
}
