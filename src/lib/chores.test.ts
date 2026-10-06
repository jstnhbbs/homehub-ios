import { describe, expect, it } from "vitest";
import {
  choreState,
  chorePeriodKey,
  isChoreOccurrence,
  nextChoreOccurrence,
  resolveChoreSchedule,
  weeklyChoreDay,
  type ChoreSchedule,
} from "./chores";

const base: ChoreSchedule = {
  repeatUnit: "day",
  repeatInterval: 1,
  days: "0,1,2,3,4,5,6",
  dueDate: null,
  dueTime: null,
};
const make = (over: Partial<ChoreSchedule>): ChoreSchedule => ({ ...base, ...over });
const dates = (schedule: ChoreSchedule, from: string, count: number) => {
  const out: string[] = [];
  let at = from;
  for (let i = 0; i < count; i++) {
    const next = nextChoreOccurrence(schedule, at);
    if (!next) break;
    out.push(next);
    at = next;
  }
  return out;
};

describe("resolving a schedule", () => {
  it("reads what apps without repeat rules send", () => {
    expect(resolveChoreSchedule({ cadence: "daily" })).toMatchObject({
      cadence: "daily",
      repeatUnit: "day",
      repeatInterval: 1,
      days: "0,1,2,3,4,5,6",
    });
    expect(resolveChoreSchedule({ cadence: "weekly", weekDay: "3" })).toMatchObject({
      cadence: "weekly",
      repeatUnit: "week",
      days: "3",
    });
    expect(resolveChoreSchedule({ cadence: "weekly" }).days).toBe("1");
  });

  it("keeps cadence readable by older apps whatever the repeat is", () => {
    expect(resolveChoreSchedule({ repeatUnit: "none" }).cadence).toBe("weekly");
    expect(resolveChoreSchedule({ repeatUnit: "month", dueDate: "2026-10-15" }).cadence).toBe("weekly");
    expect(resolveChoreSchedule({ repeatUnit: "day" }).cadence).toBe("daily");
  });

  it("takes the weekday of a weekly chore from its date when none is given", () => {
    expect(resolveChoreSchedule({ repeatUnit: "week", dueDate: "2026-10-07" }).days).toBe("3");
    expect(resolveChoreSchedule({ repeatUnit: "week", weekDay: "5", dueDate: "2026-10-07" }).days).toBe("5");
  });

  it("limits a daily chore to chosen weekdays", () => {
    const resolved = resolveChoreSchedule({ repeatUnit: "day", weekdays: ["5", "1", "3", "1"] });
    expect(resolved.days).toBe("1,3,5");
    expect(() => resolveChoreSchedule({ repeatUnit: "day", weekdays: [] })).toThrow("at least one day");
  });

  it("needs a date for anything that counts from one", () => {
    expect(() => resolveChoreSchedule({ repeatUnit: "month" })).toThrow("starts on");
    expect(() => resolveChoreSchedule({ repeatUnit: "year" })).toThrow("starts on");
    expect(() => resolveChoreSchedule({ repeatUnit: "week", repeatInterval: 2 })).toThrow("starts on");
    expect(() => resolveChoreSchedule({ repeatUnit: "day", repeatInterval: 3 })).toThrow("starts on");
    expect(resolveChoreSchedule({ repeatUnit: "week", repeatInterval: 1 }).repeatInterval).toBe(1);
  });

  it("allows a time with or without a date on a repeating chore, but not on a bare one-off", () => {
    expect(resolveChoreSchedule({ repeatUnit: "day", dueTime: "17:30" }).dueTime).toBe("17:30");
    expect(() => resolveChoreSchedule({ repeatUnit: "none", dueTime: "17:30" })).toThrow("Pick a date");
    expect(resolveChoreSchedule({ repeatUnit: "none", dueDate: "2026-10-09", dueTime: "17:30" }).dueTime).toBe("17:30");
  });

  it("refuses impossible dates, times and intervals", () => {
    expect(() => resolveChoreSchedule({ repeatUnit: "none", dueDate: "2026-02-30" })).toThrow("real date");
    expect(() => resolveChoreSchedule({ repeatUnit: "day", dueTime: "24:00" })).toThrow("valid time");
    expect(() => resolveChoreSchedule({ repeatUnit: "week", repeatInterval: 0, dueDate: "2026-10-07" })).toThrow();
    expect(() => resolveChoreSchedule({ repeatUnit: "week", repeatInterval: 100, dueDate: "2026-10-07" })).toThrow();
  });

  it("ignores the interval of a chore that does not repeat", () => {
    expect(resolveChoreSchedule({ repeatUnit: "none", repeatInterval: 5 }).repeatInterval).toBe(1);
  });
});

describe("when a chore falls", () => {
  it("falls every day, or on chosen weekdays", () => {
    expect(isChoreOccurrence(base, "2026-10-04")).toBe(true);
    const weekdays = make({ days: "1,2,3,4,5" });
    expect(isChoreOccurrence(weekdays, "2026-10-05")).toBe(true); // Monday
    expect(isChoreOccurrence(weekdays, "2026-10-04")).toBe(false); // Sunday
  });

  it("does not start before its date", () => {
    const starts = make({ dueDate: "2026-10-10" });
    expect(isChoreOccurrence(starts, "2026-10-09")).toBe(false);
    expect(isChoreOccurrence(starts, "2026-10-10")).toBe(true);
  });

  it("falls on its weekday each week", () => {
    const weekly = make({ repeatUnit: "week", days: "3" });
    expect(isChoreOccurrence(weekly, "2026-10-07")).toBe(true);
    expect(isChoreOccurrence(weekly, "2026-10-08")).toBe(false);
    expect(weeklyChoreDay("0,1,2,3,4,5,6")).toBe("1");
  });

  it("falls every second week, counted from the start", () => {
    const biweekly = make({ repeatUnit: "week", repeatInterval: 2, days: "3", dueDate: "2026-10-07" });
    expect(dates(biweekly, "2026-10-06", 3)).toEqual(["2026-10-07", "2026-10-21", "2026-11-04"]);
    expect(isChoreOccurrence(biweekly, "2026-10-14")).toBe(false);
  });

  it("counts a second week from the week of the start, even when the weekday is earlier", () => {
    // Started on a Friday, the chore is for Mondays: the Monday after is the next week, so the
    // one after that is the second.
    const biweekly = make({ repeatUnit: "week", repeatInterval: 2, days: "1", dueDate: "2026-10-09" });
    expect(isChoreOccurrence(biweekly, "2026-10-12")).toBe(false);
    expect(isChoreOccurrence(biweekly, "2026-10-19")).toBe(true);
    expect(isChoreOccurrence(biweekly, "2026-10-26")).toBe(false);
  });

  it("falls every N days from the start", () => {
    const every3 = make({ repeatInterval: 3, dueDate: "2026-10-01" });
    expect(dates(every3, "2026-09-30", 3)).toEqual(["2026-10-01", "2026-10-04", "2026-10-07"]);
  });

  it("falls on the same day of each month, and the last day when a month is short", () => {
    const monthly = make({ repeatUnit: "month", dueDate: "2026-01-31" });
    expect(dates(monthly, "2026-01-31", 4)).toEqual(["2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31"]);
  });

  it("falls every third month", () => {
    const quarterly = make({ repeatUnit: "month", repeatInterval: 3, dueDate: "2026-10-15" });
    expect(dates(quarterly, "2026-10-15", 3)).toEqual(["2027-01-15", "2027-04-15", "2027-07-15"]);
  });

  it("falls once a year, and on the 28th when a leap day has no year to fall in", () => {
    const yearly = make({ repeatUnit: "year", dueDate: "2024-02-29" });
    expect(dates(yearly, "2024-02-29", 3)).toEqual(["2025-02-28", "2026-02-28", "2027-02-28"]);
    expect(isChoreOccurrence(yearly, "2028-02-29")).toBe(true);
  });

  it("never falls when it does not repeat", () => {
    expect(isChoreOccurrence(make({ repeatUnit: "none", dueDate: "2026-10-09" }), "2026-10-09")).toBe(false);
    expect(nextChoreOccurrence(make({ repeatUnit: "none" }), "2026-10-09")).toBeNull();
  });
});

describe("period keys", () => {
  it("keys a one-off once, a weekly chore by week and the rest by day", () => {
    expect(chorePeriodKey(make({ repeatUnit: "none" }), "2026-10-07")).toBe("once");
    expect(chorePeriodKey(make({ repeatUnit: "week" }), "2026-10-07")).toBe("2026-W41");
    expect(chorePeriodKey(make({ repeatUnit: "week", repeatInterval: 2 }), "2026-10-07")).toBe("2026-10-07");
    expect(chorePeriodKey(make({ repeatUnit: "month" }), "2026-10-07")).toBe("2026-10-07");
    expect(chorePeriodKey(base, "2026-10-07")).toBe("2026-10-07");
  });
});

describe("a chore on a day", () => {
  const timezone = "America/Chicago";
  // 18:00 on 2026-10-07 in Chicago.
  const now = new Date("2026-10-07T23:00:00Z");
  const on = (chore: ChoreSchedule, localDate: string, completedAt?: Date) =>
    choreState(chore, {
      localDate,
      timezone,
      now,
      completionFor: completedAt ? () => ({ completedAt }) : undefined,
    });

  it("lists a one-off from its date and flags it overdue after", () => {
    const oneOff = make({ repeatUnit: "none", dueDate: "2026-10-09" });
    expect(on(oneOff, "2026-10-07")).toMatchObject({ dueToday: false, overdue: false, nextDueDate: "2026-10-09" });
    expect(on(oneOff, "2026-10-09")).toMatchObject({ dueToday: true, overdue: false });
    expect(on(oneOff, "2026-10-10")).toMatchObject({ dueToday: true, overdue: true });
  });

  it("lists a one-off with no date until it is done", () => {
    const todo = make({ repeatUnit: "none" });
    expect(on(todo, "2026-10-07")).toMatchObject({ dueToday: true, overdue: false, periodKey: "once" });
  });

  it("keeps a finished one-off on the list for the day it was finished, then drops it", () => {
    const oneOff = make({ repeatUnit: "none", dueDate: "2026-10-06" });
    const doneAt = new Date("2026-10-07T15:00:00Z");
    expect(on(oneOff, "2026-10-07", doneAt)).toMatchObject({ dueToday: true, completed: true, overdue: false });
    expect(on(oneOff, "2026-10-08", doneAt)).toMatchObject({ dueToday: false, completed: true });
  });

  it("is overdue once today's time has passed, but not before", () => {
    const evening = make({ dueTime: "17:30" });
    expect(on(evening, "2026-10-07").overdue).toBe(true);
    expect(on(make({ dueTime: "18:30" }), "2026-10-07").overdue).toBe(false);
    expect(on(evening, "2026-10-07", new Date()).overdue).toBe(false);
    // A day that isn't today has no "now" to be late for.
    expect(on(evening, "2026-10-08").overdue).toBe(false);
    const todayOneOff = make({ repeatUnit: "none", dueDate: "2026-10-07", dueTime: "17:30" });
    expect(on(todayOneOff, "2026-10-07").overdue).toBe(true);
  });

  it("is never behind on a repeating chore's earlier turns", () => {
    expect(on(make({ dueDate: "2026-01-01" }), "2026-10-07").overdue).toBe(false);
  });

  it("says when a repeating chore is next due", () => {
    const monthly = make({ repeatUnit: "month", dueDate: "2026-10-15" });
    expect(on(monthly, "2026-10-07")).toMatchObject({ dueToday: false, nextDueDate: "2026-10-15" });
    expect(on(monthly, "2026-10-15")).toMatchObject({ dueToday: true, nextDueDate: null });
  });
});
