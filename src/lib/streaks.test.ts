import { describe, expect, it } from "vitest";
import { addDays, computeStreak, stepStartDate, type StreakStep } from "./streaks";

const ALL = "0,1,2,3,4,5,6";
const WEEKDAYS = "1,2,3,4,5";
const today = "2026-09-18"; // a Friday

function step(id: string, startDate = "2026-08-01", days = ALL): StreakStep {
  return { id, days, startDate };
}

/** Marks a step done on each date. */
function done(entries: Record<string, string[]>) {
  return new Map(Object.entries(entries).map(([id, dates]) => [id, new Set(dates)]));
}

function range(from: string, to: string) {
  const dates: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) dates.push(d);
  return dates;
}

describe("addDays", () => {
  it("crosses month, year, and leap-day boundaries", () => {
    expect(addDays("2026-09-30", 1)).toBe("2026-10-01");
    expect(addDays("2026-12-31", 1)).toBe("2027-01-01");
    expect(addDays("2028-02-28", 1)).toBe("2028-02-29");
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
  });
});

describe("computeStreak", () => {
  it("is empty with no steps", () => {
    expect(computeStreak({ steps: [], completions: new Map(), today })).toEqual({
      current: 0,
      best: 0,
      completedToday: false,
      todayPending: false,
    });
  });

  it("counts consecutive complete days including today", () => {
    const result = computeStreak({
      steps: [step("a")],
      completions: done({ a: range("2026-09-16", "2026-09-18") }),
      today,
    });
    expect(result).toMatchObject({ current: 3, best: 3, completedToday: true, todayPending: false });
  });

  it("does not break a streak while today is still in progress", () => {
    const result = computeStreak({
      steps: [step("a")],
      completions: done({ a: range("2026-09-15", "2026-09-17") }),
      today,
    });
    expect(result).toMatchObject({ current: 3, completedToday: false, todayPending: true });
  });

  it("breaks on a missed day that has passed", () => {
    const result = computeStreak({
      steps: [step("a")],
      completions: done({ a: ["2026-09-14", "2026-09-16", "2026-09-17", "2026-09-18"] }),
      today,
    });
    expect(result.current).toBe(3);
    expect(result.best).toBe(3);
  });

  it("is zero after a missed yesterday, even if today is done later", () => {
    const result = computeStreak({
      steps: [step("a")],
      completions: done({ a: ["2026-09-15", "2026-09-16"] }),
      today,
    });
    expect(result.current).toBe(0);
    expect(result.todayPending).toBe(true);
  });

  it("remembers the best run after the current one is shorter", () => {
    const result = computeStreak({
      steps: [step("a")],
      completions: done({ a: [...range("2026-09-01", "2026-09-05"), "2026-09-17", "2026-09-18"] }),
      today,
    });
    expect(result.current).toBe(2);
    expect(result.best).toBe(5);
  });

  it("needs every scheduled step: a partly done day breaks the streak", () => {
    const result = computeStreak({
      steps: [step("a"), step("b")],
      completions: done({
        a: range("2026-09-14", "2026-09-18"),
        b: ["2026-09-14", "2026-09-16", "2026-09-17", "2026-09-18"],
      }),
      today,
    });
    expect(result.current).toBe(3);
  });

  it("skips days with nothing scheduled instead of breaking on them", () => {
    // Weekday-only routine: Fri 9/11 done, weekend off, Mon-Fri done.
    const result = computeStreak({
      steps: [step("a", "2026-08-01", WEEKDAYS)],
      completions: done({ a: ["2026-09-11", ...range("2026-09-14", "2026-09-18")] }),
      today,
    });
    expect(result.current).toBe(6);
  });

  it("does not let a newly added step erase the past", () => {
    const result = computeStreak({
      steps: [step("a"), step("b", "2026-09-18")],
      completions: done({ a: range("2026-09-10", "2026-09-18"), b: ["2026-09-18"] }),
      today,
    });
    expect(result).toMatchObject({ current: 9, completedToday: true });
  });

  it("makes a newly added step count from its start date", () => {
    const result = computeStreak({
      steps: [step("a"), step("b", "2026-09-18")],
      completions: done({ a: range("2026-09-10", "2026-09-18") }),
      today,
    });
    expect(result).toMatchObject({ current: 8, completedToday: false, todayPending: true });
  });

  it("ignores steps scheduled only on other weekdays today", () => {
    // Today is a Friday; a Monday-only step is not pending.
    const result = computeStreak({
      steps: [step("mon", "2026-08-01", "1")],
      completions: done({ mon: ["2026-09-14"] }),
      today,
    });
    expect(result).toMatchObject({ completedToday: false, todayPending: false });
    expect(result.current).toBeGreaterThanOrEqual(1);
  });

  it("only looks back a limited number of days", () => {
    const result = computeStreak({
      steps: [step("a", "2020-01-01")],
      completions: done({ a: range("2026-09-01", "2026-09-18") }),
      today,
      lookbackDays: 30,
    });
    expect(result.current).toBe(18);
  });
});

describe("stepStartDate", () => {
  const routineCreatedDate = "2026-07-01";

  it("uses the step's own creation date when it has one", () => {
    expect(stepStartDate({ createdDate: "2026-09-10", firstCompletionDate: "2026-09-12", routineCreatedDate })).toBe(
      "2026-09-10",
    );
  });

  it("falls back to the first completion for older steps", () => {
    expect(stepStartDate({ createdDate: null, firstCompletionDate: "2026-08-20", routineCreatedDate })).toBe(
      "2026-08-20",
    );
  });

  it("falls back to the routine's creation for steps never completed", () => {
    expect(stepStartDate({ createdDate: null, firstCompletionDate: null, routineCreatedDate })).toBe("2026-07-01");
  });
});
