import { describe, expect, it } from "vitest";
import { localDateIn, weekDates, weekKey, weekOfLocalDate } from "./dates";

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

  describe("the week of a calendar date", () => {
    it("starts on the chosen weekday and lists seven dates", () => {
      // Monday 12 October 2026.
      expect(weekOfLocalDate("2026-10-12", 1)).toEqual([
        "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18",
      ]);
      expect(weekOfLocalDate("2026-10-12", 0)).toEqual([
        "2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17",
      ]);
    });

    it("keeps a Sunday in the week that ends on it for Monday-first weeks", () => {
      expect(weekOfLocalDate("2026-10-18", 1)[0]).toBe("2026-10-12");
      expect(weekOfLocalDate("2026-10-18", 1)[6]).toBe("2026-10-18");
    });

    it("crosses month and year ends", () => {
      expect(weekOfLocalDate("2026-12-31", 1)).toEqual([
        "2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03",
      ]);
    });

    it("does not depend on the server's time zone (the Kiritimati case)", () => {
      // A household in Kiritimati (UTC+14) on Monday 12 October used to get 5 to 11 October from a UTC server.
      const original = process.env.TZ;
      try {
        for (const zone of ["UTC", "Pacific/Kiritimati", "Pacific/Pago_Pago", "America/Chicago"]) {
          process.env.TZ = zone;
          expect(weekOfLocalDate("2026-10-12", 1)[0]).toBe("2026-10-12");
        }
      } finally {
        if (original === undefined) delete process.env.TZ;
        else process.env.TZ = original;
      }
    });
  });
});
