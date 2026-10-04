import { randomInt } from "node:crypto";
import { RateLimitedError } from "@/lib/errors";
import { checkRateLimit } from "@/lib/rate-limit";

// No I, O, 0 or 1, so a code read aloud or off a screenshot is hard to mistype.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const INVITE_CODE_LENGTH = 10;

/**
 * A random invite code, 50 bits. Households made before this used 8 hex characters (32 bits); those
 * codes keep working, which is why lookups only normalise a code and never check its length.
 */
export function generateInviteCode() {
  let code = "";
  for (let index = 0; index < INVITE_CODE_LENGTH; index += 1) {
    code += ALPHABET[randomInt(ALPHABET.length)];
  }
  return code;
}

/** A parent code and a guest code that differ, as a household needs both. */
export function generateInviteCodePair() {
  const inviteCode = generateInviteCode();
  let guestInviteCode = generateInviteCode();
  while (guestInviteCode === inviteCode) {
    guestInviteCode = generateInviteCode();
  }
  return { inviteCode, guestInviteCode };
}

/** What a person typed, as it is stored: upper case, without spaces or hyphens. */
export function normalizeInviteCode(value: string) {
  return value.trim().toUpperCase().replace(/[\s-]+/g, "");
}

/** The caller's address, as the platform's proxy reports it. */
export function clientAddress(headers: Headers) {
  const forwarded = headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || headers.get("x-real-ip")?.trim() || null;
}

/**
 * Guessing an invite code is the one way into a household that needs no invitation, so tries are
 * limited per account and per address. Throws `RateLimitedError` once either is used up.
 */
export async function assertMayTryInviteCode(userId: string, address: string | null) {
  const [byUser, byAddress] = await Promise.all([
    checkRateLimit("invite-code-user", userId, { limit: 10, windowMs: 15 * 60 * 1000 }),
    address
      ? checkRateLimit("invite-code-address", address, { limit: 40, windowMs: 60 * 60 * 1000 })
      : true,
  ]);
  if (!byUser || !byAddress) {
    throw new RateLimitedError("Too many invite code attempts. Try again in a little while.");
  }
}
