import { formatInTimeZone, fromZonedTime } from "date-fns-tz";
import { format, parseISO } from "date-fns";
import Link from "next/link";

type DayEvent = {
  eventId: string;
  title: string;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  color: string;
  calendarName: string;
  location: string | null;
};

export function CalendarDayView({
  events,
  selectedDate,
  timezone,
  today,
  hrefForEvent,
}: {
  events: DayEvent[];
  selectedDate: string;
  timezone: string;
  today: string;
  hrefForEvent: (event: DayEvent) => string;
}) {
  const allDayEvents = events.filter((event) => event.allDay);
  const timedEvents = events.filter((event) => !event.allDay);
  const hours = Array.from({ length: 17 }, (_, index) => index + 6);
  const selected = parseISO(selectedDate);
  const isToday = selectedDate === today;

  return (
    <div>
      <div className="flex items-center justify-between border-b border-[var(--line)] px-5 py-4">
        <div>
          <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
            {format(selected, "EEEE")}
          </p>
          <h2 className="font-display text-2xl font-semibold">
            {format(selected, "MMMM d, yyyy")}
          </h2>
        </div>
        {isToday && (
          <span className="rounded-full bg-[var(--sun-soft)] px-3 py-1 text-xs font-bold">
            Today
          </span>
        )}
      </div>

      {allDayEvents.length > 0 && (
        <div className="border-b border-[var(--line)] px-5 py-4">
          <p className="text-xs font-extrabold uppercase tracking-wider text-[var(--muted)]">
            All day
          </p>
          <div className="mt-3 space-y-2">
            {allDayEvents.map((event, index) => (
              <EventChip
                key={`${event.eventId}-${index}`}
                event={event}
                timezone={timezone}
                href={hrefForEvent(event)}
              />
            ))}
          </div>
        </div>
      )}

      <div className="divide-y divide-[var(--line)]">
        {hours.map((hour) => {
          const hourEvents = timedEvents.filter(
            (event) =>
              Number(formatInTimeZone(event.startsAt, timezone, "H")) === hour,
          );
          const label = formatInTimeZone(
            fromZonedTime(
              `${selectedDate}T${String(hour).padStart(2, "0")}:00:00`,
              timezone,
            ),
            timezone,
            "h a",
          );

          return (
            <div
              key={hour}
              className="grid min-h-20 grid-cols-[4.5rem_minmax(0,1fr)] gap-3 px-5 py-3"
            >
              <p className="pt-0.5 text-xs font-bold text-[var(--muted)]">
                {label}
              </p>
              <div className="space-y-2">
                {hourEvents.length ? (
                  hourEvents.map((event, index) => (
                    <EventChip
                      key={`${event.eventId}-${index}`}
                      event={event}
                      timezone={timezone}
                      href={hrefForEvent(event)}
                      showEndTime
                    />
                  ))
                ) : (
                  <div className="h-full min-h-8 rounded-xl border border-dashed border-transparent" />
                )}
              </div>
            </div>
          );
        })}
      </div>

      {events.length === 0 && (
        <div className="flex min-h-64 flex-col items-center justify-center p-8 text-center">
          <p className="text-sm font-bold">Nothing scheduled</p>
          <p className="mt-1 text-xs text-[var(--muted)]">
            Use the agenda panel to add an event.
          </p>
        </div>
      )}
    </div>
  );
}

function EventChip({
  event,
  timezone,
  href,
  showEndTime = false,
}: {
  event: DayEvent;
  timezone: string;
  href: string;
  showEndTime?: boolean;
}) {
  return (
    <Link
      href={href}
      className="block rounded-xl bg-white/75 px-3 py-2 text-sm font-bold"
      style={{ borderLeft: `4px solid ${event.color}` }}
    >
      <p>{event.title}</p>
      <p className="mt-1 text-xs font-normal text-[var(--muted)]">
        {showEndTime
          ? `${formatInTimeZone(event.startsAt, timezone, "h:mm a")} – ${formatInTimeZone(event.endsAt, timezone, "h:mm a")}`
          : event.calendarName}
        {event.location ? ` · ${event.location}` : ""}
      </p>
    </Link>
  );
}
