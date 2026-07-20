import { eq } from "drizzle-orm";
import { db } from "@/db/client";
import { calendarConnections } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  requireMobileHousehold,
} from "@/lib/mobile/http";

export async function GET() {
  try {
    const household = await requireMobileHousehold();
    const rows = await db
      .select({
        id: calendarConnections.id,
        householdId: calendarConnections.householdId,
        provider: calendarConnections.provider,
        accountEmail: calendarConnections.accountEmail,
        appleId: calendarConnections.appleId,
        status: calendarConnections.status,
        errorMessage: calendarConnections.errorMessage,
        lastSyncedAt: calendarConnections.lastSyncedAt,
        createdAt: calendarConnections.createdAt,
        updatedAt: calendarConnections.updatedAt,
      })
      .from(calendarConnections)
      .where(eq(calendarConnections.householdId, household.id));
    return mobileJson(rows);
  } catch (error) {
    return handleMobileError(error);
  }
}
