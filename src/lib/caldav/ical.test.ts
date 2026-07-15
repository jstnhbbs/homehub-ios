import { describe, expect, it } from "vitest";
import { expandIcalEvent, makeIcalEvent, parseIcalEvent } from "./ical";

describe("iCalendar normalization", () => {
  it("creates and parses an event", () => {
    const raw = makeIcalEvent({
      uid: "family-event@homehub",
      title: "Soccer practice",
      startsAt: new Date("2026-07-14T22:00:00.000Z"),
      endsAt: new Date("2026-07-14T23:00:00.000Z"),
      location: "Community field",
    });
    const event = parseIcalEvent(raw);
    expect(event.uid).toBe("family-event@homehub");
    expect(event.title).toBe("Soccer practice");
    expect(event.location).toBe("Community field");
  });

  it("expands recurring events inside a requested range", () => {
    const raw = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "BEGIN:VEVENT",
      "UID:repeat@homehub",
      "DTSTART:20260713T130000Z",
      "DTEND:20260713T133000Z",
      "RRULE:FREQ=DAILY;COUNT=5",
      "SUMMARY:Morning check-in",
      "END:VEVENT",
      "END:VCALENDAR",
    ].join("\r\n");
    const events = expandIcalEvent(
      raw,
      new Date("2026-07-14T00:00:00.000Z"),
      new Date("2026-07-16T23:59:59.000Z"),
    );
    expect(events).toHaveLength(3);
    expect(events.every((event) => event.title === "Morning check-in")).toBe(true);
  });
});
