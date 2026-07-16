import { randomUUID } from "node:crypto";
import type { calendar_v3 } from "googleapis";
import { fromZonedTime } from "date-fns-tz";
import { makeIcalEvent, type ParsedCalendarEvent } from "@/lib/caldav/ical";

function parseGoogleDate(
  value: calendar_v3.Schema$EventDateTime | null | undefined,
  fallbackTimezone: string,
) {
  if (!value) return null;
  if (value.date) {
    const startsAt = fromZonedTime(`${value.date}T00:00:00`, fallbackTimezone);
    return { startsAt, allDay: true };
  }
  if (value.dateTime) {
    return {
      startsAt: new Date(value.dateTime),
      allDay: false,
    };
  }
  return null;
}

export function googleEventToParsed(
  event: calendar_v3.Schema$Event,
  fallbackTimezone: string,
): ParsedCalendarEvent {
  const start = parseGoogleDate(event.start, fallbackTimezone);
  const end = parseGoogleDate(event.end, fallbackTimezone);
  if (!start || !end) throw new Error("Google event is missing start or end.");
  const uid = event.iCalUID ?? event.id ?? randomUUID();
  return {
    uid,
    title: event.summary?.trim() || "Untitled event",
    description: event.description?.trim() || null,
    location: event.location?.trim() || null,
    startsAt: start.startsAt,
    endsAt: end.startsAt,
    allDay: start.allDay && end.allDay,
    recurrenceRule: event.recurrence?.[0] ?? null,
  };
}

export function googleEventToRawIcal(
  event: calendar_v3.Schema$Event,
  fallbackTimezone: string,
) {
  const parsed = googleEventToParsed(event, fallbackTimezone);
  return makeIcalEvent({
    uid: parsed.uid,
    title: parsed.title,
    description: parsed.description ?? undefined,
    location: parsed.location ?? undefined,
    startsAt: parsed.startsAt,
    endsAt: parsed.endsAt,
    allDay: parsed.allDay,
  });
}

export function parsedEventToGoogleBody(input: {
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay?: boolean;
  uid?: string;
}): calendar_v3.Schema$Event {
  const allDay = input.allDay ?? false;
  const formatDate = (date: Date) => date.toISOString().slice(0, 10);
  if (allDay) {
    return {
      summary: input.title,
      description: input.description,
      location: input.location,
      iCalUID: input.uid,
      start: { date: formatDate(input.startsAt) },
      end: { date: formatDate(input.endsAt) },
    };
  }
  return {
    summary: input.title,
    description: input.description,
    location: input.location,
    iCalUID: input.uid,
    start: { dateTime: input.startsAt.toISOString() },
    end: { dateTime: input.endsAt.toISOString() },
  };
}
