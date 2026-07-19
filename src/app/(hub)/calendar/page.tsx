import { and, eq } from "drizzle-orm";
import {
  addDays,
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
  subDays,
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
import { calendarSyncStatus } from "@/lib/calendar/connections";
import { defaultEventFieldValues } from "@/lib/calendar/event-input";
import { CalendarSync } from "@/components/calendar-sync";
import { CalendarEventForm } from "@/components/calendar-event-form";
import { CalendarDayView } from "@/components/calendar-day-view";
import { db } from "@/db/client";
import {
  calendarConnections,
  calendarEvents,
  calendars,
  profiles,
} from "@/db/schema";
import { birthdayEventsInRange } from "@/lib/birthdays";
import { expandIcalEvent } from "@/lib/caldav/ical";
import { localDateIn, formatLocalDate } from "@/lib/dates";
import { weekdayLabels, parseWeekStartsOn } from "@/lib/calendar/week-start";
import { requireHousehold } from "@/lib/household";
import { canManageHousehold } from "@/lib/household-roles";
import {
  createCalendarEvent,
  deleteCalendarEvent,
  updateCalendarEvent,
} from "./actions";

type CalendarView = "month" | "week" | "day";

function parseView(value?: string): CalendarView {
  if (value === "week") return "week";
  if (value === "day") return "day";
  return "month";
}

function viewLabel(view: CalendarView) {
  if (view === "week") return "Week";
  if (view === "day") return "Day";
  return "Month";
}

export default async function CalendarPage({
  searchParams,
}: {
  searchParams: Promise<{
    view?: string;
    date?: string;
    selected?: string;
    q?: string;
    edit?: string;
  }>;
}) {
  const household = await requireHousehold();
  const params = await searchParams;
  const today = localDateIn(household.timezone);
  const view = parseView(params.view);
  const anchorDate = validDate(params.date) ?? today;
  const anchor = parseISO(anchorDate);
  const selectedDate =
    view === "day"
      ? anchorDate
      : validDate(params.selected) ?? anchorDate;
  const query = params.q?.trim() ?? "";
  const editEventId = params.edit?.trim() ?? "";
  const weekStartsOn = parseWeekStartsOn(household.weekStartsOn);

  const firstDay =
    view === "month"
      ? startOfWeek(startOfMonth(anchor), { weekStartsOn })
      : view === "week"
        ? startOfWeek(anchor, { weekStartsOn })
        : anchor;
  const lastDay =
    view === "month"
      ? endOfWeek(endOfMonth(anchor), { weekStartsOn })
      : view === "week"
        ? endOfWeek(anchor, { weekStartsOn })
        : anchor;
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
        .where(eq(calendarConnections.householdId, household.id)),
      db
        .select({
          id: calendars.id,
          displayName: calendars.displayName,
          color: calendars.color,
          provider: calendarConnections.provider,
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
          description: calendarEvents.description,
          color: calendars.color,
          calendarName: calendars.displayName,
          provider: calendarConnections.provider,
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

  const calendarStatus = calendarSyncStatus(connections, household.timezone);
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
        description: occurrence.description || event.description,
        provider: event.provider,
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
    view === "month"
      ? subMonths(anchor, 1)
      : view === "week"
        ? subWeeks(anchor, 1)
        : subDays(anchor, 1),
    "yyyy-MM-dd",
  );
  const nextDate = format(
    view === "month"
      ? addMonths(anchor, 1)
      : view === "week"
        ? addWeeks(anchor, 1)
        : addDays(anchor, 1),
    "yyyy-MM-dd",
  );
  const dayViewEvents = eventsForDate(
    occurrences,
    selectedDate,
    household.timezone,
  );
  const canManage = canManageHousehold(household.role);

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
        {canManage && (
          <CalendarSync
            connected={calendarStatus.connected}
            updatedLabel={calendarStatus.updatedLabel}
            lastSyncedAt={calendarStatus.lastSyncedAt}
            syncIntervalMinutes={household.calendarSyncIntervalMinutes}
          />
        )}
      </div>

      <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex rounded-xl border border-[var(--line)] bg-[var(--tile)] p-1">
          {(["month", "week", "day"] as const).map((option) => (
            <Link
              key={option}
              href={calendarHref({
                view: option,
                date: option === "day" ? selectedDate : anchorDate,
                selected: option === "day" ? selectedDate : selectedDate,
                q: query,
              })}
              className={`rounded-lg px-4 py-2 text-sm font-bold ${
                view === option
                  ? "bg-[var(--tile-solid)] shadow-sm"
                  : "text-[var(--muted)]"
              }`}
            >
              {viewLabel(option)}
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
            className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--line)] bg-[var(--tile)]"
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
            className="flex h-10 items-center rounded-xl border border-[var(--line)] bg-[var(--tile)] px-4 text-sm font-bold"
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
            className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--line)] bg-[var(--tile)]"
            aria-label={`Next ${view}`}
          >
            <ChevronRight size={18} />
          </Link>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-[minmax(0,1fr)_320px] gap-5 max-lg:grid-cols-1">
        <section className="hub-card min-w-0 overflow-hidden">
          {view === "day" ? (
            <CalendarDayView
              events={dayViewEvents}
              selectedDate={selectedDate}
              timezone={household.timezone}
              today={today}
              hrefForEvent={(event) =>
                calendarHref({
                  view: "day",
                  date: selectedDate,
                  selected: selectedDate,
                  q: query,
                  edit: event.eventId,
                })
              }
            />
          ) : (
            <>
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
                {weekdayLabels(weekStartsOn).map((day) => (
                  <div
                    key={day}
                    className="border-r border-[var(--line)] px-3 py-2 text-center text-xs font-extrabold uppercase tracking-wider text-[var(--muted)] last:border-r-0"
                  >
                    {day}
                  </div>
                ))}
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
                      } ${outsideMonth ? "bg-[var(--tile-quiet)] text-[var(--muted)]" : ""} ${
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
                              className="block truncate rounded-lg bg-[var(--tile)] px-2 py-1.5 text-[11px] font-bold"
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
            </>
          )}
        </section>

        <aside className="hub-card h-fit min-h-[600px] p-5 max-lg:min-h-0 max-md:p-4">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
                Agenda
              </p>
              <h2 className="font-display mt-1 text-2xl font-semibold">
                {formatLocalDate(selectedDate, household.timezone, "EEEE, MMMM d")}
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
              selectedEvents.map((event, index) => {
                const fieldValues = defaultEventFieldValues(
                  household.timezone,
                  event.startsAt,
                  event.endsAt,
                  event.allDay,
                );
                const editableCalendars = calendarList.filter(
                  (calendar) =>
                    !event.isBirthday && calendar.provider === event.provider,
                );

                return (
                <details
                  key={`${event.eventId}-${event.startsAt.toISOString()}-${index}`}
                  className="rounded-2xl bg-[var(--tile)] p-3 text-sm"
                  style={{ borderLeft: `4px solid ${event.color}` }}
                  open={
                    editEventId === event.eventId ||
                    (editEventId === "" && index === 0 && selectedEvents.length === 1)
                  }
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
                  {event.description && (
                    <p className="mt-2 text-xs leading-5 text-[var(--muted)]">
                      {event.description}
                    </p>
                  )}
                  {event.isBirthday ? (
                    canManage ? (
                      <Link
                        href={`/settings/profiles/${event.profileId}`}
                        className="mt-3 block rounded-xl bg-[var(--tile-solid)] px-3 py-2 text-center text-xs font-bold"
                      >
                        Edit family profile
                      </Link>
                    ) : null
                  ) : canManage ? (
                    <>
                      <div className="mt-3">
                        <CalendarEventForm
                          action={updateCalendarEvent}
                          calendars={editableCalendars}
                          timezone={household.timezone}
                          submitLabel="Save changes"
                          eventId={event.eventId}
                          defaultValues={{
                            title: event.title,
                            calendarId: event.calendarId,
                            startsAt: fieldValues.startsAt,
                            endsAt: fieldValues.endsAt,
                            allDay: event.allDay,
                            location: event.location ?? "",
                            description: event.description ?? "",
                          }}
                        />
                      </div>
                      <form action={deleteCalendarEvent} className="mt-2">
                        <input
                          type="hidden"
                          name="eventId"
                          value={event.eventId}
                        />
                        <button className="flex w-full items-center justify-center gap-1 py-1 text-xs font-bold text-[var(--coral)]">
                          <Trash2 size={12} /> Delete event
                        </button>
                      </form>
                    </>
                  ) : null}
                </details>
              );
              })
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

          {canManage && calendarStatus.connected && calendarList.length > 0 ? (
            <details className="mt-5 border-t border-[var(--line)] pt-4">
              <summary className="flex cursor-pointer list-none items-center gap-2 text-sm font-bold">
                <CalendarPlus size={17} className="text-[var(--sage)]" />
                Add an event
              </summary>
              <CalendarEventForm
                action={createCalendarEvent}
                calendars={calendarList}
                timezone={household.timezone}
                submitLabel="Add event"
                defaultValues={{
                  title: "",
                  calendarId: calendarList[0]?.id ?? "",
                  startsAt: `${selectedDate}T09:00`,
                  endsAt: `${selectedDate}T10:00`,
                  allDay: false,
                  location: "",
                  description: "",
                }}
              />
            </details>
          ) : canManage ? (
            <div className="mt-5 border-t border-[var(--line)] pt-4 text-center">
              <p className="text-sm text-[var(--muted)]">
                Connect a calendar to add and edit events on the hub.
              </p>
              <Link href="/settings/calendar" className="hub-button mt-4">
                Calendar settings
              </Link>
            </div>
          ) : null}
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
  edit,
}: {
  view: CalendarView;
  date: string;
  selected: string;
  q?: string;
  edit?: string;
}) {
  const params = new URLSearchParams({
    view,
    date,
    selected: view === "day" ? date : selected,
  });
  if (q) params.set("q", q);
  if (edit) params.set("edit", edit);
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
