"use server";

import { eq } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { db } from "@/db/client";
import { calendarConnections, calendars, households } from "@/db/schema";
import {
  connectICloud,
  disconnectICloud,
} from "@/lib/caldav/client";
import { disconnectGoogleCalendar } from "@/lib/google/calendar";
import { syncHouseholdCalendars } from "@/lib/calendar/sync";
import { parseCalendarSyncIntervalMinutes } from "@/lib/calendar/sync-interval";
import { requireParentHousehold } from "@/lib/household";
import { checkRateLimit } from "@/lib/rate-limit";

export async function connectCalendar(formData: FormData) {
  const household = await requireParentHousehold();
  const allowed = await checkRateLimit("calendar-connect", household.id, {
    limit: 5,
    windowMs: 15 * 60 * 1000,
  });
  if (!allowed) throw new Error("Too many connection attempts. Try again later.");
  const input = z
    .object({
      username: z.string().trim().email(),
      password: z.string().trim().min(16).max(32),
    })
    .parse({
      username: formData.get("username"),
      password: formData.get("password"),
    });
  await connectICloud({
    householdId: household.id,
    username: input.username,
    appSpecificPassword: input.password.replaceAll("-", ""),
  });
  revalidatePath("/", "layout");
}

export async function disconnectCalendar(formData: FormData) {
  const household = await requireParentHousehold();
  const provider = z.enum(["icloud", "google"]).parse(formData.get("provider"));
  if (provider === "google") {
    await disconnectGoogleCalendar(household.id);
  } else {
    await disconnectICloud(household.id);
  }
  revalidatePath("/", "layout");
}

export async function updateCalendarSelection(formData: FormData) {
  const household = await requireParentHousehold();
  const selectedIds = new Set(
    z.array(z.string().uuid()).parse(formData.getAll("calendarId")),
  );
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
  revalidatePath("/", "layout");
}

export async function updateCalendarSyncInterval(formData: FormData) {
  const household = await requireParentHousehold();
  const intervalMinutes = parseCalendarSyncIntervalMinutes(
    formData.get("intervalMinutes"),
  );
  await db
    .update(households)
    .set({ calendarSyncIntervalMinutes: intervalMinutes })
    .where(eq(households.id, household.id));
  revalidatePath("/", "layout");
}
