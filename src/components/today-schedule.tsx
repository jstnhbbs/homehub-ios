"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";

type ScheduleEvent = {
  eventId: string;
  title: string;
  startsAt: string;
  endsAt: string;
  allDay: boolean;
  color: string;
  calendarName: string;
};

function upcomingEvents(events: ScheduleEvent[], now: Date) {
  return events.filter(
    (event) => event.allDay || new Date(event.endsAt) > now,
  );
}

export function TodaySchedule({
  events,
  timezone,
  connected,
  initialNow,
}: {
  events: ScheduleEvent[];
  timezone: string;
  connected: boolean;
  initialNow: string;
}) {
  const [now, setNow] = useState(() => new Date(initialNow));
  const visibleEvents = useMemo(
    () => upcomingEvents(events, now).slice(0, 5),
    [events, now],
  );

  useEffect(() => {
    const tick = () => setNow(new Date());
    const interval = window.setInterval(tick, 60_000);
    return () => window.clearInterval(interval);
  }, []);

  useEffect(() => {
    const nextEndMs = events
      .filter((event) => !event.allDay)
      .map((event) => new Date(event.endsAt).getTime())
      .filter((time) => time > now.getTime())
      .sort((a, b) => a - b)[0];

    if (nextEndMs === undefined) return;

    const timeout = window.setTimeout(
      () => setNow(new Date()),
      nextEndMs - Date.now() + 50,
    );
    return () => window.clearTimeout(timeout);
  }, [events, now]);

  const timeFormatter = useMemo(
    () =>
      new Intl.DateTimeFormat("en-US", {
        timeZone: timezone,
        hour: "numeric",
        minute: "2-digit",
      }),
    [timezone],
  );

  if (!visibleEvents.length) {
    return (
      <EmptyState
        text={
          connected
            ? events.length
              ? "Nothing left on the calendar today."
              : "Nothing on the calendar today."
            : "Connect a calendar to see today’s events."
        }
        href="/settings/calendar"
      />
    );
  }

  return (
    <>
      {visibleEvents.map((event, index) => (
        <div
          key={`${event.eventId}-${event.startsAt}-${index}`}
          className="flex min-h-14 items-center gap-3 rounded-2xl bg-[var(--tile)] px-3"
        >
          <span
            className="h-9 w-1.5 rounded-full"
            style={{ background: event.color }}
          />
          <div className="min-w-0">
            <p className="truncate font-bold">{event.title}</p>
            <p className="text-xs text-[var(--muted)]">
              {event.allDay
                ? "All day"
                : timeFormatter.format(new Date(event.startsAt))}
              {" · "}
              {event.calendarName}
            </p>
          </div>
        </div>
      ))}
    </>
  );
}

function EmptyState({ text, href }: { text: string; href: string }) {
  return (
    <div className="flex min-h-24 items-center justify-center rounded-2xl border border-dashed border-[var(--line)] p-4 text-center">
      <Link href={href} className="text-sm font-bold text-[var(--muted)]">
        {text}
      </Link>
    </div>
  );
}
