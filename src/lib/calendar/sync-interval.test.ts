import { describe, expect, it } from "vitest";
import {
  calendarSyncCooldownMs,
  calendarSyncIntervalMs,
  parseCalendarSyncIntervalMinutes,
} from "./sync-interval";

describe("calendar sync interval", () => {
  it("parses supported intervals", () => {
    expect(parseCalendarSyncIntervalMinutes("15")).toBe(15);
    expect(parseCalendarSyncIntervalMinutes("0")).toBe(0);
    expect(parseCalendarSyncIntervalMinutes("999")).toBe(15);
  });

  it("derives interval and cooldown durations", () => {
    expect(calendarSyncIntervalMs(15)).toBe(900_000);
    expect(calendarSyncCooldownMs(15)).toBe(840_000);
    expect(calendarSyncCooldownMs(0)).toBe(0);
  });
});
