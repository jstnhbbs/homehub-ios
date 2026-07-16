import { eq } from "drizzle-orm";
import { NextResponse } from "next/server";
import { db } from "@/db/client";
import { calendarConnections, households } from "@/db/schema";
import { syncHouseholdCalendars } from "@/lib/calendar/sync";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const connected = await db
    .select({ householdId: households.id })
    .from(calendarConnections)
    .innerJoin(
      households,
      eq(calendarConnections.householdId, households.id),
    );
  const results = [];
  for (const item of connected) {
    results.push(await syncHouseholdCalendars(item.householdId, false));
  }
  return NextResponse.json({ households: results.length, results });
}
