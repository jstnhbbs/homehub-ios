import { describe, expect, it } from "vitest";
import {
  birthdayDateInYear,
  birthdayEventsInRange,
  upcomingBirthdays,
} from "./birthdays";

const profile = {
  id: "child-1",
  name: "Jamie",
  color: "#d87861",
  birthday: "2020-07-18",
};

describe("birthdays", () => {
  it("uses February 28 for leap-day birthdays in non-leap years", () => {
    expect(birthdayDateInYear("2020-02-29", 2027)).toBe("2027-02-28");
    expect(birthdayDateInYear("2020-02-29", 2028)).toBe("2028-02-29");
  });

  it("creates an annual all-day family calendar event", () => {
    const events = birthdayEventsInRange(
      [profile],
      "2026-07-13",
      "2026-07-19",
      "America/Chicago",
    );

    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({
      title: "Jamie’s birthday",
      allDay: true,
      calendarName: "Family birthdays",
      isBirthday: true,
    });
    expect(events[0].startsAt.toISOString()).toBe("2026-07-18T05:00:00.000Z");
  });

  it("words an anniversary's calendar event as an anniversary", () => {
    const events = birthdayEventsInRange(
      [{ id: "a-1", name: "Alex & Sam", color: "#4f7c6d", birthday: "2016-07-18", kind: "anniversary" }],
      "2026-07-13",
      "2026-07-19",
      "America/Chicago",
    );

    expect(events[0]).toMatchObject({
      title: "Alex & Sam’s anniversary",
      calendarName: "Family anniversaries",
      allDay: true,
    });
  });

  it("returns birthdays within the reminder window", () => {
    expect(upcomingBirthdays([profile], "2026-07-15")).toMatchObject([
      { daysUntil: 3, localDate: "2026-07-18" },
    ]);
  });
});
