import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { RateLimitedError } from "@/lib/errors";
import { generateInviteCodePair } from "@/lib/invite-codes";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
  serializeHousehold,
} from "@/lib/mobile/http";

const bodySchema = z.object({ which: z.enum(["parent", "guest", "both"]) });

/**
 * Replaces the household's invite code (or the guest code, or both) with a fresh one. The old code
 * stops working at once, which is the point: it is how a code that was shared too widely, or sent
 * to the wrong person, gets taken back. People already in the household are not affected.
 */
export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const allowed = await checkRateLimit("invite-codes-regenerate", household.id, {
      limit: 10,
      windowMs: 60 * 60 * 1000,
    });
    if (!allowed) throw new RateLimitedError("Too many code changes. Try again in a little while.");

    const { which } = bodySchema.parse(await parseJsonBody(request));
    const fresh = generateInviteCodePair();
    const next = {
      inviteCode: which === "guest" ? household.inviteCode : fresh.inviteCode,
      guestInviteCode: which === "parent" ? household.guestInviteCode : fresh.guestInviteCode,
    };

    await db
      .update(households)
      .set({ ...next, updatedAt: new Date() })
      .where(eq(households.id, household.id));

    return mobileJson(serializeHousehold({ ...household, ...next }));
  } catch (error) {
    return handleMobileError(error);
  }
}
