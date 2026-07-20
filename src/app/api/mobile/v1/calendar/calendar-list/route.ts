import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { calendarConnections, calendars } from "@/db/schema";
import { syncHouseholdCalendars } from "@/lib/calendar/sync";
import { listHouseholdCalendars } from "@/lib/mobile/calendar-events";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileParentHousehold();
    const rows = await listHouseholdCalendars(household.id);
    return mobileJson(rows);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function PATCH(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const input = z
      .object({
        calendarIds: z.array(z.string().uuid()),
      })
      .parse(await parseJsonBody(request));

    const selectedIds = new Set(input.calendarIds);
    const householdCalendars = await db
      .select({ id: calendars.id })
      .from(calendars)
      .innerJoin(
        calendarConnections,
        eq(calendars.connectionId, calendarConnections.id),
      )
      .where(eq(calendarConnections.householdId, household.id));

    for (const calendar of householdCalendars) {
      await db
        .update(calendars)
        .set({ enabled: selectedIds.has(calendar.id) })
        .where(eq(calendars.id, calendar.id));
    }

    await syncHouseholdCalendars(household.id, true);
    return mobileJson(await listHouseholdCalendars(household.id));
  } catch (error) {
    return handleMobileError(error);
  }
}
