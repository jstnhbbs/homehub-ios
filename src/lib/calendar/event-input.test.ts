import { describe, expect, it } from "vitest";
import { eventTimesFromForm } from "./event-input";

describe("eventTimesFromForm", () => {
  it("extends same-day all-day events by one day", () => {
    const result = eventTimesFromForm(
      {
        calendarId: "00000000-0000-4000-8000-000000000001",
        title: "Trip",
        startsAt: "2026-07-20",
        endsAt: "2026-07-20",
        allDay: true,
      },
      "America/Chicago",
    );
    expect(result.allDay).toBe(true);
    expect(result.endsAt.getTime() - result.startsAt.getTime()).toBe(
      86_400_000,
    );
  });
});
