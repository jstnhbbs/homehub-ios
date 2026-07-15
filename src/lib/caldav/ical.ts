import ICAL from "ical.js";
import { fromZonedTime } from "date-fns-tz";

export type ParsedCalendarEvent = {
  uid: string;
  title: string;
  description: string | null;
  location: string | null;
  startsAt: Date;
  endsAt: Date;
  allDay: boolean;
  recurrenceRule: string | null;
};

function registerEmbeddedTimezones(root: ICAL.Component) {
  for (const timezone of root.getAllSubcomponents("vtimezone")) {
    ICAL.TimezoneService.register(timezone);
  }
}

function floatingDateTime(value: ICAL.Time) {
  const pad = (part: number) => String(part).padStart(2, "0");
  return `${value.year}-${pad(value.month)}-${pad(value.day)}T${pad(value.hour)}:${pad(value.minute)}:${pad(value.second)}`;
}

function fromIcalTime(value: ICAL.Time, fallbackTimezone: string) {
  if (value.isDate || value.zone?.tzid === "floating") {
    return fromZonedTime(floatingDateTime(value), fallbackTimezone);
  }
  return value.toJSDate();
}

export function parseIcalEvent(
  rawIcal: string,
  fallbackTimezone = "UTC",
): ParsedCalendarEvent {
  const root = new ICAL.Component(ICAL.parse(rawIcal));
  registerEmbeddedTimezones(root);
  const vevent = root.getFirstSubcomponent("vevent");
  if (!vevent) throw new Error("Calendar object does not contain an event.");
  const event = new ICAL.Event(vevent);
  const recurrence = vevent.getFirstPropertyValue("rrule");
  return {
    uid: event.uid,
    title: event.summary || "Untitled event",
    description: event.description || null,
    location: event.location || null,
    startsAt: fromIcalTime(event.startDate, fallbackTimezone),
    endsAt: fromIcalTime(event.endDate, fallbackTimezone),
    allDay: event.startDate.isDate,
    recurrenceRule: recurrence ? String(recurrence) : null,
  };
}

export function expandIcalEvent(
  rawIcal: string,
  rangeStart: Date,
  rangeEnd: Date,
  fallbackTimezone = "UTC",
) {
  const root = new ICAL.Component(ICAL.parse(rawIcal));
  registerEmbeddedTimezones(root);
  const vevent = root.getFirstSubcomponent("vevent");
  if (!vevent) return [];
  const event = new ICAL.Event(vevent);
  const duration = event.endDate.subtractDate(event.startDate);
  const recurrence = vevent.getFirstPropertyValue("rrule");

  if (!event.isRecurring()) {
    const parsed = parseIcalEvent(rawIcal, fallbackTimezone);
    return parsed.endsAt >= rangeStart && parsed.startsAt <= rangeEnd
      ? [parsed]
      : [];
  }

  const iterator = event.iterator();
  const occurrences: ParsedCalendarEvent[] = [];
  for (let index = 0; index < 500; index += 1) {
    const next = iterator.next();
    if (!next) break;
    const startsAt = fromIcalTime(next, fallbackTimezone);
    if (startsAt > rangeEnd) break;
    const endsAt = next.clone();
    endsAt.addDuration(duration);
    const occurrenceEndsAt = fromIcalTime(endsAt, fallbackTimezone);
    if (occurrenceEndsAt < rangeStart) continue;
    occurrences.push({
      uid: event.uid,
      title: event.summary || "Untitled event",
      description: event.description || null,
      location: event.location || null,
      startsAt,
      endsAt: occurrenceEndsAt,
      allDay: next.isDate,
      recurrenceRule: recurrence ? String(recurrence) : "recurring",
    });
  }
  return occurrences;
}

function icalDate(date: Date, allDay: boolean) {
  if (allDay) return date.toISOString().slice(0, 10).replaceAll("-", "");
  return date.toISOString().replaceAll("-", "").replaceAll(":", "").slice(0, 15) + "Z";
}

function escapeIcal(value: string) {
  return value
    .replaceAll("\\", "\\\\")
    .replaceAll("\n", "\\n")
    .replaceAll(",", "\\,")
    .replaceAll(";", "\\;");
}

export function makeIcalEvent(input: {
  uid: string;
  title: string;
  description?: string;
  location?: string;
  startsAt: Date;
  endsAt: Date;
  allDay?: boolean;
}) {
  const allDay = input.allDay ?? false;
  const type = allDay ? ";VALUE=DATE" : "";
  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Home Hub//Family Calendar//EN",
    "CALSCALE:GREGORIAN",
    "BEGIN:VEVENT",
    `UID:${input.uid}`,
    `DTSTAMP:${icalDate(new Date(), false)}`,
    `DTSTART${type}:${icalDate(input.startsAt, allDay)}`,
    `DTEND${type}:${icalDate(input.endsAt, allDay)}`,
    `SUMMARY:${escapeIcal(input.title)}`,
    input.description
      ? `DESCRIPTION:${escapeIcal(input.description)}`
      : undefined,
    input.location ? `LOCATION:${escapeIcal(input.location)}` : undefined,
    "END:VEVENT",
    "END:VCALENDAR",
  ]
    .filter(Boolean)
    .join("\r\n")
    .concat("\r\n");
}
