import { and, eq } from "drizzle-orm";
import {
  addMonths,
  addWeeks,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  isSameMonth,
  isValid,
  parseISO,
  startOfMonth,
  startOfWeek,
  subMonths,
  subWeeks,
} from "date-fns";
import { formatInTimeZone, fromZonedTime } from "date-fns-tz";
import {
  CalendarPlus,
  ChevronLeft,
  ChevronRight,
  MapPin,
  Search,
  Trash2,
} from "lucide-react";
import Link from "next/link";
import { CalendarSync } from "@/components/calendar-sync";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  profiles,
} from "@/db/schema";
import { birthdayEventsInRange } from "@/lib/birthdays";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { localDateIn } from "@/lib/dates";
import { requireHousehold } from "@/lib/household";
import {
  createCalendarEvent,
  deleteCalendarEvent,
  updateCalendarEvent,
} from "./actions";

type CalendarView = "month" | "week";

export default async function CalendarPage({
  searchParams,
}: {
  searchParams: Promise<{
    view?: string;
    date?: string;
    selected?: string;
    q?: string;
  }>;
}) {
  const household = await requireHousehold();
  const params = await searchParams;
  const today = localDateIn(household.timezone);
  const view: CalendarView = params.view === "week" ? "week" : "month";
  const anchorDate = validDate(params.date) ?? today;
  const anchor = parseISO(anchorDate);
  const selectedDate = validDate(params.selected) ?? anchorDate;
  const query = params.q?.trim() ?? "";

  const firstDay =
    view === "month"
      ? startOfWeek(startOfMonth(anchor), { weekStartsOn: 1 })
      : startOfWeek(anchor, { weekStartsOn: 1 });
  const lastDay =
    view === "month"
      ? endOfWeek(endOfMonth(anchor), { weekStartsOn: 1 })
      : endOfWeek(anchor, { weekStartsOn: 1 });
  const days = eachDayOfInterval({ start: firstDay, end: lastDay });
  const firstDate = format(firstDay, "yyyy-MM-dd");
  const lastDate = format(lastDay, "yyyy-MM-dd");
  const rangeStart = fromZonedTime(`${firstDate}T00:00:00`, household.timezone);
  const rangeEnd = fromZonedTime(`${lastDate}T23:59:59`, household.timezone);

  const [connections, calendarList, cachedEvents, familyProfiles] =
    await Promise.all([
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
      db
        .select({
          id: profiles.id,
          name: profiles.name,
          color: profiles.color,
          birthday: profiles.birthday,
        })
        .from(profiles)
        .where(eq(profiles.householdId, household.id)),
    ]);

  const connection = connections[0];
  const occurrences = [
    ...cachedEvents.flatMap((event) =>
      expandIcalEvent(
        event.rawIcal,
        rangeStart,
        rangeEnd,
        household.timezone,
      ).map((occurrence) => ({
        ...occurrence,
        eventId: event.id,
        calendarId: event.calendarId,
        color: event.color,
        calendarName: event.calendarName,
        location: occurrence.location || event.location,
        isBirthday: false as const,
        profileId: null,
      })),
    ),
    ...birthdayEventsInRange(
      familyProfiles,
      firstDate,
      lastDate,
      household.timezone,
    ),
  ].filter((event) =>
    query
      ? `${event.title} ${event.location ?? ""} ${event.calendarName}`
          .toLocaleLowerCase()
          .includes(query.toLocaleLowerCase())
      : true,
  );
  const selectedEvents = eventsForDate(
    occurrences,
    selectedDate,
    household.timezone,
  );
  const previousDate = format(
    view === "month" ? subMonths(anchor, 1) : subWeeks(anchor, 1),
    "yyyy-MM-dd",
  );
  const nextDate = format(
    view === "month" ? addMonths(anchor, 1) : addWeeks(anchor, 1),
    "yyyy-MM-dd",
  );

  return (
    <div className="mx-auto max-w-[1600px]">
      <div className="flex items-end justify-between gap-4 max-md:flex-col max-md:items-start">
        <div>
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

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex rounded-xl border border-[var(--line)] bg-white/55 p-1">
          {(["month", "week"] as const).map((option) => (
            <Link
              key={option}
              href={calendarHref({
                view: option,
                date: anchorDate,
                selected: selectedDate,
                q: query,
              })}
              className={`rounded-lg px-4 py-2 text-sm font-bold capitalize ${
                view === option
                  ? "bg-white shadow-sm"
                  : "text-[var(--muted)]"
              }`}
            >
              {option === "month" ? "Month" : "Week"}
            </Link>
          ))}
        </div>

        <form className="relative min-w-64 max-sm:order-3 max-sm:w-full">
          <input type="hidden" name="view" value={view} />
          <input type="hidden" name="date" value={anchorDate} />
          <input type="hidden" name="selected" value={selectedDate} />
          <Search
            size={15}
            className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-[var(--muted)]"
          />
          <input
            name="q"
            defaultValue={query}
            className="hub-input !min-h-10 !rounded-xl !py-2 !pl-9 text-sm"
            placeholder="Search events…"
            aria-label="Search events"
          />
        </form>

        <div className="flex items-center gap-2">
          <Link
            href={calendarHref({
              view,
              date: previousDate,
              selected: previousDate,
              q: query,
            })}
            className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--line)] bg-white/55"
            aria-label={`Previous ${view}`}
          >
            <ChevronLeft size={18} />
          </Link>
          <Link
            href={calendarHref({
              view,
              date: today,
              selected: today,
              q: query,
            })}
            className="flex h-10 items-center rounded-xl border border-[var(--line)] bg-white/55 px-4 text-sm font-bold"
          >
            Today
          </Link>
          <Link
            href={calendarHref({
              view,
              date: nextDate,
              selected: nextDate,
              q: query,
            })}
            className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--line)] bg-white/55"
            aria-label={`Next ${view}`}
          >
            <ChevronRight size={18} />
          </Link>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-[minmax(0,1fr)_320px] gap-5 max-lg:grid-cols-1">
        <section className="hub-card min-w-0 overflow-hidden">
          <div className="flex items-center justify-between border-b border-[var(--line)] px-5 py-4">
            <h2 className="font-display text-2xl font-semibold">
              {view === "month"
                ? format(anchor, "MMMM yyyy")
                : `${format(firstDay, "MMM d")} – ${format(lastDay, "MMM d, yyyy")}`}
            </h2>
            <span className="rounded-full bg-[var(--coral-soft)] px-3 py-1 text-xs font-bold">
              Family
            </span>
          </div>
          <div className="overflow-x-auto">
            <div className="min-w-[700px]">
              <div className="grid grid-cols-7 border-b border-[var(--line)]">
                {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map(
                  (day) => (
                    <div
                      key={day}
                      className="border-r border-[var(--line)] px-3 py-2 text-center text-xs font-extrabold uppercase tracking-wider text-[var(--muted)] last:border-r-0"
                    >
                      {day}
                    </div>
                  ),
                )}
              </div>
              <div className="grid grid-cols-7">
                {days.map((day, index) => {
                  const localDate = format(day, "yyyy-MM-dd");
                  const dayEvents = eventsForDate(
                    occurrences,
                    localDate,
                    household.timezone,
                  );
                  const selected = localDate === selectedDate;
                  const current = localDate === today;
                  const outsideMonth =
                    view === "month" && !isSameMonth(day, anchor);

                  return (
                    <div
                      key={localDate}
                      className={`relative border-b border-r border-[var(--line)] p-2 last:border-r-0 ${
                        view === "month" ? "min-h-28" : "min-h-[520px]"
                      } ${outsideMonth ? "bg-black/[0.015] text-[var(--muted)]" : ""} ${
                        selected ? "bg-[var(--sun-soft)]/35" : ""
                      } ${index % 7 === 6 ? "!border-r-0" : ""}`}
                    >
                      <Link
                        href={calendarHref({
                          view,
                          date: anchorDate,
                          selected: localDate,
                          q: query,
                        })}
                        className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-extrabold ${
                          current
                            ? "bg-[var(--sun)] text-white"
                            : selected
                              ? "ring-2 ring-[var(--sun)]"
                              : ""
                        }`}
                        aria-label={`Show agenda for ${format(day, "MMMM d, yyyy")}`}
                      >
                        {format(day, "d")}
                      </Link>
                      <div className="mt-2 space-y-1">
                        {dayEvents
                          .slice(0, view === "month" ? 3 : 8)
                          .map((event, eventIndex) => (
                            <Link
                              key={`${event.eventId}-${event.startsAt.toISOString()}-${eventIndex}`}
                              href={calendarHref({
                                view,
                                date: anchorDate,
                                selected: localDate,
                                q: query,
                              })}
                              className="block truncate rounded-lg bg-white/75 px-2 py-1.5 text-[11px] font-bold"
                              style={{
                                borderLeft: `3px solid ${event.color}`,
                              }}
                              title={event.title}
                            >
                              {!event.allDay &&
                                `${formatInTimeZone(event.startsAt, household.timezone, "h:mm")} `}
                              {event.title}
                            </Link>
                          ))}
                        {dayEvents.length > (view === "month" ? 3 : 8) && (
                          <p className="px-1 text-[10px] font-bold text-[var(--muted)]">
                            +{dayEvents.length - (view === "month" ? 3 : 8)} more
                          </p>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <aside className="hub-card h-fit min-h-[600px] p-5 max-lg:min-h-0 max-md:p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
                Agenda
              </p>
              <h2 className="font-display mt-1 text-2xl font-semibold">
                {format(parseISO(selectedDate), "EEEE, MMMM d")}
              </h2>
            </div>
            {selectedDate === today && (
              <span className="rounded-full bg-[var(--sun-soft)] px-2.5 py-1 text-xs font-bold">
                Today
              </span>
            )}
          </div>

          <div className="mt-5 space-y-2">
            {selectedEvents.length ? (
              selectedEvents.map((event, index) => (
                <details
                  key={`${event.eventId}-${event.startsAt.toISOString()}-${index}`}
                  className="rounded-2xl bg-white/70 p-3 text-sm"
                  style={{ borderLeft: `4px solid ${event.color}` }}
                >
                  <summary className="cursor-pointer list-none">
                    <p className="font-extrabold">{event.title}</p>
                    <p className="mt-1 text-xs text-[var(--muted)]">
                      {event.allDay
                        ? "All day"
                        : formatInTimeZone(
                            event.startsAt,
                            household.timezone,
                            "h:mm a",
                          )}
                      {" · "}
                      {event.calendarName}
                    </p>
                  </summary>
                  {event.location && (
                    <p className="mt-2 flex items-center gap-1 text-xs text-[var(--muted)]">
                      <MapPin size={12} /> {event.location}
                    </p>
                  )}
                  {event.isBirthday ? (
                    <Link
                      href={`/settings/profiles/${event.profileId}`}
                      className="mt-3 block rounded-xl bg-white px-3 py-2 text-center text-xs font-bold"
                    >
                      Edit family profile
                    </Link>
                  ) : (
                    <>
                      <form
                        action={updateCalendarEvent}
                        className="mt-3 space-y-2"
                      >
                        <input
                          type="hidden"
                          name="eventId"
                          value={event.eventId}
                        />
                        <input
                          type="hidden"
                          name="calendarId"
                          value={event.calendarId}
                        />
                        <input
                          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                          name="title"
                          defaultValue={event.title}
                        />
                        <input
                          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                          name="startsAt"
                          type="datetime-local"
                          defaultValue={formatInTimeZone(
                            event.startsAt,
                            household.timezone,
                            "yyyy-MM-dd'T'HH:mm",
                          )}
                        />
                        <input
                          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                          name="endsAt"
                          type="datetime-local"
                          defaultValue={formatInTimeZone(
                            event.endsAt,
                            household.timezone,
                            "yyyy-MM-dd'T'HH:mm",
                          )}
                        />
                        <input
                          className="hub-input !min-h-9 !rounded-lg !p-2 text-xs"
                          name="location"
                          defaultValue={event.location ?? ""}
                          placeholder="Location"
                        />
                        <button className="hub-button !min-h-9 w-full !py-1 text-xs">
                          Save changes
                        </button>
                      </form>
                      <form action={deleteCalendarEvent} className="mt-2">
                        <input
                          type="hidden"
                          name="eventId"
                          value={event.eventId}
                        />
                        <button className="flex w-full items-center justify-center gap-1 py-1 text-xs font-bold text-[var(--coral)]">
                          <Trash2 size={12} /> Delete
                        </button>
                      </form>
                    </>
                  )}
                </details>
              ))
            ) : (
              <div className="flex min-h-44 flex-col items-center justify-center rounded-2xl border border-dashed border-[var(--line)] p-5 text-center">
                <CalendarPlus size={28} className="text-[var(--sun)]" />
                <p className="mt-3 text-sm font-bold">No events on this day</p>
                {query && (
                  <p className="mt-1 text-xs text-[var(--muted)]">
                    Try clearing your search.
                  </p>
                )}
              </div>
            )}
          </div>

          {connection ? (
            <details className="mt-5 border-t border-[var(--line)] pt-4">
              <summary className="flex cursor-pointer list-none items-center gap-2 text-sm font-bold">
                <CalendarPlus size={17} className="text-[var(--sage)]" />
                Add an event
              </summary>
              <form action={createCalendarEvent} className="mt-4 space-y-3">
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
                    defaultValue={`${selectedDate}T09:00`}
                    required
                  />
                </label>
                <label className="block">
                  <span className="mb-1 block text-xs font-bold">Ends</span>
                  <input
                    name="endsAt"
                    type="datetime-local"
                    className="hub-input"
                    defaultValue={`${selectedDate}T10:00`}
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
            </details>
          ) : (
            <div className="mt-5 border-t border-[var(--line)] pt-4 text-center">
              <p className="text-sm text-[var(--muted)]">
                Connect iCloud to add the rest of your family schedule.
              </p>
              <Link href="/settings/calendar" className="hub-button mt-4">
                Connect Apple Calendar
              </Link>
            </div>
          )}
        </aside>
      </div>
    </div>
  );
}

function validDate(value?: string) {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  return isValid(parseISO(value)) ? value : null;
}

function calendarHref({
  view,
  date,
  selected,
  q,
}: {
  view: CalendarView;
  date: string;
  selected: string;
  q?: string;
}) {
  const params = new URLSearchParams({ view, date, selected });
  if (q) params.set("q", q);
  return `/calendar?${params.toString()}`;
}

function eventsForDate<
  T extends {
    startsAt: Date;
  },
>(events: T[], localDate: string, timezone: string) {
  return events
    .filter(
      (event) =>
        formatInTimeZone(event.startsAt, timezone, "yyyy-MM-dd") === localDate,
    )
    .sort((a, b) => a.startsAt.getTime() - b.startsAt.getTime());
}
