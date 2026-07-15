import ICAL from "ical.js";

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

function fromIcalTime(value: ICAL.Time) {
  return value.toJSDate();
}

export function parseIcalEvent(rawIcal: string): ParsedCalendarEvent {
  const root = new ICAL.Component(ICAL.parse(rawIcal));
  const vevent = root.getFirstSubcomponent("vevent");
  if (!vevent) throw new Error("Calendar object does not contain an event.");
  const event = new ICAL.Event(vevent);
  const recurrence = vevent.getFirstPropertyValue("rrule");
  return {
    uid: event.uid,
    title: event.summary || "Untitled event",
    description: event.description || null,
    location: event.location || null,
    startsAt: fromIcalTime(event.startDate),
    endsAt: fromIcalTime(event.endDate),
    allDay: event.startDate.isDate,
    recurrenceRule: recurrence ? String(recurrence) : null,
  };
}

export function expandIcalEvent(
  rawIcal: string,
  rangeStart: Date,
  rangeEnd: Date,
) {
  const root = new ICAL.Component(ICAL.parse(rawIcal));
  const vevent = root.getFirstSubcomponent("vevent");
  if (!vevent) return [];
  const event = new ICAL.Event(vevent);
  const duration = event.endDate.subtractDate(event.startDate);
  const recurrence = vevent.getFirstPropertyValue("rrule");

  if (!event.isRecurring()) {
    const parsed = parseIcalEvent(rawIcal);
    return parsed.endsAt >= rangeStart && parsed.startsAt <= rangeEnd
      ? [parsed]
      : [];
  }

  const iterator = event.iterator();
  const occurrences: ParsedCalendarEvent[] = [];
  for (let index = 0; index < 500; index += 1) {
    const next = iterator.next();
    if (!next) break;
    const startsAt = next.toJSDate();
    if (startsAt > rangeEnd) break;
    const endsAt = next.clone();
    endsAt.addDuration(duration);
    if (endsAt.toJSDate() < rangeStart) continue;
    occurrences.push({
      uid: event.uid,
      title: event.summary || "Untitled event",
      description: event.description || null,
      location: event.location || null,
      startsAt,
      endsAt: endsAt.toJSDate(),
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
