import { and, eq } from "drizzle-orm";
import { format } from "date-fns";
import { formatInTimeZone, fromZonedTime } from "date-fns-tz";
import { CalendarPlus, MapPin, Trash2 } from "lucide-react";
import Link from "next/link";
import { CalendarSync } from "@/components/calendar-sync";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
} from "@/db/schema";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { weekDates } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";
import {
  createCalendarEvent,
  deleteCalendarEvent,
  updateCalendarEvent,
} from "./actions";

export default async function CalendarPage() {
  const household = await requireHousehold();
  const days = weekDates();
  const firstDate = format(days[0], "yyyy-MM-dd");
  const lastDate = format(days[6], "yyyy-MM-dd");
  const rangeStart = fromZonedTime(`${firstDate}T00:00:00`, household.timezone);
  const rangeEnd = fromZonedTime(`${lastDate}T23:59:59`, household.timezone);

  const [connections, calendarList, cachedEvents] = await Promise.all([
    db
      .select()
      .from(calendarConnections)
      .where(eq(calendarConnections.householdId, household.id))
      .limit(1),
    db
      .select({
        id: calendars.id,
        displayName: calendars.displayName,
        color: calendars.color,
      })
      .from(calendars)
      .innerJoin(
        calendarConnections,
        eq(calendars.connectionId, calendarConnections.id),
      )
      .where(
        and(
          eq(calendarConnections.householdId, household.id),
          eq(calendars.enabled, true),
        ),
      ),
    db
      .select({
        id: calendarEvents.id,
        calendarId: calendarEvents.calendarId,
        rawIcal: calendarEvents.rawIcal,
        color: calendars.color,
        calendarName: calendars.displayName,
        location: calendarEvents.location,
      })
      .from(calendarEvents)
      .innerJoin(calendars, eq(calendarEvents.calendarId, calendars.id))
      .innerJoin(
        calendarConnections,
        eq(calendars.connectionId, calendarConnections.id),
      )
      .where(
        and(
          eq(calendarConnections.householdId, household.id),
          eq(calendars.enabled, true),
        ),
      ),
  ]);
  const connection = connections[0];
  const occurrences = cachedEvents.flatMap((event) =>
    expandIcalEvent(event.rawIcal, rangeStart, rangeEnd).map((occurrence) => ({
      ...occurrence,
      eventId: event.id,
      calendarId: event.calendarId,
      color: event.color,
      calendarName: event.calendarName,
      location: occurrence.location || event.location,
    })),
  );

  return (
    <div className="mx-auto max-w-[1500px]">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div className="min-w-0">
          <p className="text-sm font-bold uppercase tracking-[0.18em] text-[var(--sage)]">
            Everyone, all in one place
          </p>
          <h1 className="font-display mt-1 text-4xl font-semibold max-md:text-3xl">
            Family calendar
          </h1>
        </div>
        <CalendarSync
          connected={Boolean(connection)}
          lastSyncedAt={connection?.lastSyncedAt?.toISOString()}
        />
      </div>

      {!connection ? (
        <section className="hub-card mt-6 flex min-h-[430px] flex-col items-center justify-center p-8 text-center">
          <CalendarPlus size={42} className="text-[var(--sage)]" />
          <h2 className="font-display mt-4 text-3xl font-semibold">
            Bring in your Apple calendars
          </h2>
          <p className="mt-2 max-w-md text-[var(--muted)]">
            Connect iCloud once to see and manage the family week from this hub.
          </p>
          <Link href="/settings/calendar" className="hub-button mt-6">
            Connect Apple Calendar
          </Link>
        </section>
      ) : (
        <div className="mt-6 grid grid-cols-[1fr_300px] gap-5 max-md:mt-4 max-md:grid-cols-1 max-md:gap-3">
          <section className="hub-card overflow-hidden">
            <div className="grid grid-cols-7 max-md:grid-cols-1">
              {days.map((day) => {
                const localDate = format(day, "yyyy-MM-dd");
                const dayEvents = occurrences
                  .filter(
                    (event) =>
                      formatInTimeZone(
                        event.startsAt,
                        household.timezone,
                        "yyyy-MM-dd",
                      ) === localDate,
                  )
                  .sort(
                    (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
                  );
                return (
                  <div
                    key={localDate}
                    className="min-h-[510px] border-r border-[var(--line)] last:border-r-0 max-md:min-h-0 max-md:border-b max-md:border-r-0 max-md:last:border-b-0"
                  >
                    <div className="border-b border-[var(--line)] p-3 text-center">
                      <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
                        {format(day, "EEE")}
                      </p>
                      <p className="font-display text-2xl font-semibold">
                        {format(day, "d")}
                      </p>
                    </div>
                    <div className="space-y-2 p-2">
                      {dayEvents.map((event, index) => (
                        <details
                          key={`${event.eventId}-${event.startsAt.toISOString()}-${index}`}
                          className="rounded-xl bg-white/70 p-2.5 text-xs"
                          style={{ borderLeft: `4px solid ${event.color}` }}
                        >
                          <summary className="cursor-pointer list-none">
                            <p className="font-extrabold">{event.title}</p>
                            <p className="mt-1 text-[var(--muted)]">
                              {event.allDay
                                ? "All day"
                                : formatInTimeZone(
                                    event.startsAt,
                                    household.timezone,
                                    "h:mm a",
                                  )}
                            </p>
                          </summary>
                          {event.location && (
                            <p className="mt-2 flex gap-1 text-[var(--muted)]">
                              <MapPin size={12} /> {event.location}
                            </p>
                          )}
                          <form action={updateCalendarEvent} className="mt-3 space-y-2">
                            <input type="hidden" name="eventId" value={event.eventId} />
                            <input type="hidden" name="calendarId" value={event.calendarId} />
                            <input className="hub-input !min-h-9 !rounded-lg !p-2 text-xs" name="title" defaultValue={event.title} />
                            <input
                              className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                              name="startsAt"
                              type="datetime-local"
                              defaultValue={formatInTimeZone(event.startsAt, household.timezone, "yyyy-MM-dd'T'HH:mm")}
                            />
                            <input
                              className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                              name="endsAt"
                              type="datetime-local"
                              defaultValue={formatInTimeZone(event.endsAt, household.timezone, "yyyy-MM-dd'T'HH:mm")}
                            />
                            <input className="hub-input !min-h-9 !rounded-lg !p-2 text-xs" name="location" defaultValue={event.location ?? ""} placeholder="Location" />
                            <button className="hub-button !min-h-9 w-full !py-1 text-xs">Save changes</button>
                          </form>
                          <form action={deleteCalendarEvent} className="mt-2">
                            <input type="hidden" name="eventId" value={event.eventId} />
                            <button className="flex w-full items-center justify-center gap-1 py-1 font-bold text-[var(--coral)]">
                              <Trash2 size={12} /> Delete
                            </button>
                          </form>
                        </details>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
          <aside className="hub-card h-fit p-5 max-md:p-4">
            <div className="flex items-center gap-2">
              <CalendarPlus size={20} className="text-[var(--sage)]" />
              <h2 className="font-display text-2xl font-semibold">New event</h2>
            </div>
            <form action={createCalendarEvent} className="mt-5 space-y-3">
              <input
                name="title"
                className="hub-input"
                placeholder="Event title"
                required
              />
              <select name="calendarId" className="hub-input" required>
                {calendarList.map((calendar) => (
                  <option key={calendar.id} value={calendar.id}>
                    {calendar.displayName}
                  </option>
                ))}
              </select>
              <label className="block">
                <span className="mb-1 block text-xs font-bold">Starts</span>
                <input
                  name="startsAt"
                  type="datetime-local"
                  className="hub-input"
                  required
                />
              </label>
              <label className="block">
                <span className="mb-1 block text-xs font-bold">Ends</span>
                <input
                  name="endsAt"
                  type="datetime-local"
                  className="hub-input"
                  required
                />
              </label>
              <input
                name="location"
                className="hub-input"
                placeholder="Location (optional)"
              />
              <button className="hub-button w-full">Add to iCloud</button>
            </form>
          </aside>
        </div>
      )}
    </div>
  );
}
