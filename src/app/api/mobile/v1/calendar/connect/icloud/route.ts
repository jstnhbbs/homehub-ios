import { z } from "zod";
import { connectICloud } from "@/lib/caldav/client";
import { checkRateLimit } from "@/lib/rate-limit";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const allowed = await checkRateLimit("calendar-connect", household.id, {
      limit: 5,
      windowMs: 15 * 60 * 1000,
    });
    if (!allowed) {
      throw new Error("Too many connection attempts. Try again later.");
    }

    const input = z
      .object({
        username: z.string().trim().email(),
        password: z.string().trim().min(16).max(32),
      })
      .parse(await parseJsonBody(request));

    await connectICloud({
      householdId: household.id,
      username: input.username,
      appSpecificPassword: input.password.replaceAll("-", ""),
    });

    return mobileJson({ ok: true });
  } catch (error) {
    return handleMobileError(error);
  }
}
