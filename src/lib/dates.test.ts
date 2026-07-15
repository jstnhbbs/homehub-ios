import { describe, expect, it } from "vitest";
import { localDateIn, weekDates, weekKey } from "./dates";

describe("household date helpers", () => {
  it("uses the household timezone around midnight", () => {
    const instant = new Date("2026-07-15T02:00:00.000Z");
    expect(localDateIn("America/Chicago", instant)).toBe("2026-07-14");
    expect(localDateIn("Asia/Tokyo", instant)).toBe("2026-07-15");
  });

  it("creates Monday-first weeks and stable weekly reset keys", () => {
    const dates = weekDates(new Date("2026-07-16T12:00:00.000Z"));
    expect(dates).toHaveLength(7);
    expect(dates[0].getDay()).toBe(1);
    expect(weekKey(dates[0])).toBe(weekKey(dates[6]));
  });
});
