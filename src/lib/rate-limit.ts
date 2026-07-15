import { createHash } from "node:crypto";
import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { rateLimits } from "@/db/schema";

export async function checkRateLimit(
  scope: string,
  identifier: string,
  options: { limit: number; windowMs: number },
) {
  const key = createHash("sha256")
    .update(`${scope}:${identifier}`)
    .digest("hex");
  const now = new Date();
  const existing = await db
    .select()
    .from(rateLimits)
    .where(eq(rateLimits.key, key))
    .limit(1);

  if (
    !existing[0] ||
    now.getTime() - existing[0].lastRequest >= options.windowMs
  ) {
    await db
      .insert(rateLimits)
      .values({ key, count: 1, lastRequest: now.getTime() })
      .onConflictDoUpdate({
        target: rateLimits.key,
        set: { count: 1, lastRequest: now.getTime() },
      });
    return true;
  }
  if (existing[0].count >= options.limit) return false;
  await db
    .update(rateLimits)
    .set({ count: existing[0].count + 1 })
    .where(eq(rateLimits.key, key));
  return true;
}
