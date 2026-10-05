import { createHash } from "node:crypto";
import { sql } from "drizzle-orm";
import { db } from "@/db/client";
import { rateLimits } from "@/db/schema";

/**
 * Counts one request against `identifier` within `scope` and says whether it is allowed.
 *
 * The count is a fixed window that starts at the first request: up to `limit` requests are allowed,
 * the rest are refused until `windowMs` after that first request, when a fresh window begins.
 *
 * It is a single statement, so it is safe when requests arrive together. An earlier version read
 * the count, then wrote it back, and a burst of simultaneous requests all read the same low number
 * and were all let through. Refused requests are counted too, but they do not move the start of the
 * window, so hammering the endpoint does not extend how long someone is locked out.
 */
export async function checkRateLimit(
  scope: string,
  identifier: string,
  options: { limit: number; windowMs: number },
) {
  const key = createHash("sha256")
    .update(`${scope}:${identifier}`)
    .digest("hex");
  const now = Date.now();
  const windowOver = sql`${now} - ${rateLimits.lastRequest} >= ${options.windowMs}`;

  const [row] = await db
    .insert(rateLimits)
    .values({ key, count: 1, lastRequest: now })
    .onConflictDoUpdate({
      target: rateLimits.key,
      // Both columns are worked out from the row as it was before this statement changed it.
      set: {
        count: sql`CASE WHEN ${windowOver} THEN 1 ELSE ${rateLimits.count} + 1 END`,
        lastRequest: sql`CASE WHEN ${windowOver} THEN ${now} ELSE ${rateLimits.lastRequest} END`,
      },
    })
    .returning({ count: rateLimits.count });

  return row.count <= options.limit;
}
