import { NextResponse } from "next/server";
import { syncHouseholdCalendars } from "@/lib/calendar/sync";
import { getCurrentHousehold, getSession } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import { checkRateLimit } from "@/lib/rate-limit";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const url = new URL(request.url);
  const force = url.searchParams.get("force") === "true";
  if (force) {
    const allowed = await checkRateLimit("calendar-sync", session.user.id, {
      limit: 10,
      windowMs: 5 * 60 * 1000,
    });
    if (!allowed) {
      return NextResponse.json({ error: "Too many sync requests" }, { status: 429 });
    }
  }
  const household = await getCurrentHousehold();
  if (!household) {
    return NextResponse.json({ error: "No household" }, { status: 403 });
  }
  if (force && !canManageHousehold(household.role)) {
    return NextResponse.json({ error: "Forbidden" }, { status: 403 });
  }
  const result = await syncHouseholdCalendars(household.id, force);
  return NextResponse.json(result);
}
