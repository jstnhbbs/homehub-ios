import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import { parseCalendarSyncIntervalMinutes } from "@/lib/calendar/sync-interval";
import { parseWeekStartsOn } from "@/lib/calendar/week-start";
import { getCurrentHousehold } from "@/lib/household";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
  serializeHousehold,
} from "@/lib/mobile/http";

export async function PATCH(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        weekStartsOn: z.number().int().min(0).max(6).optional(),
        calendarSyncIntervalMinutes: z.number().int().optional(),
      })
      .parse(await parseJsonBody(request));

    const updates: Partial<typeof households.$inferInsert> = {};
    if (input.weekStartsOn !== undefined) {
      updates.weekStartsOn = parseWeekStartsOn(input.weekStartsOn);
    }
    if (input.calendarSyncIntervalMinutes !== undefined) {
      updates.calendarSyncIntervalMinutes = parseCalendarSyncIntervalMinutes(
        input.calendarSyncIntervalMinutes,
      );
    }

    if (Object.keys(updates).length === 0) {
      throw new Error("Nothing to update.");
    }

    await db
      .update(households)
      .set(updates)
      .where(eq(households.id, household.id));

    const current = await getCurrentHousehold();
    return mobileJson(serializeHousehold(current!));
  } catch (error) {
    return handleMobileError(error);
  }
}
