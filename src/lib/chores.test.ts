import { describe, expect, it } from "vitest";
import {
  choreCadenceDetail,
  choreDaysForCadence,
  isChoreDueOnDate,
  isChoreOverdue,
  weeklyChoreDay,
} from "./chores";

describe("chore helpers", () => {
  it("stores a single weekday for weekly chores", () => {
    expect(choreDaysForCadence("weekly", "3")).toBe("3");
    expect(choreDaysForCadence("weekly", undefined)).toBe("1");
    expect(choreDaysForCadence("daily", "3")).toBe("0,1,2,3,4,5,6");
  });

  it("formats weekly chore details with the selected day", () => {
    expect(choreCadenceDetail("weekly", "3")).toBe("Once a week · Wednesday");
    expect(choreCadenceDetail("daily", "0,1,2,3,4,5,6")).toBe("Every day");
  });

  it("falls back to Monday for legacy weekly chores with all days", () => {
    expect(weeklyChoreDay("0,1,2,3,4,5,6")).toBe("1");
  });

  it("checks whether a weekly chore is due on a given local date", () => {
    expect(
      isChoreDueOnDate("weekly", "3", "2026-07-15", "America/Chicago"),
    ).toBe(true);
    expect(
      isChoreDueOnDate("weekly", "3", "2026-07-14", "America/Chicago"),
    ).toBe(false);
    expect(
      isChoreDueOnDate("daily", "0,1,2,3,4,5,6", "2026-07-14", "America/Chicago"),
    ).toBe(true);
  });

  it("is overdue once its due date has passed and it's still unfinished", () => {
    expect(isChoreOverdue("2026-07-14", "2026-07-15", false)).toBe(true);
  });

  it("is not overdue on or before its due date", () => {
    expect(isChoreOverdue("2026-07-15", "2026-07-15", false)).toBe(false);
    expect(isChoreOverdue("2026-07-16", "2026-07-15", false)).toBe(false);
  });

  it("is never overdue once completed, or with no due date set", () => {
    expect(isChoreOverdue("2026-07-14", "2026-07-15", true)).toBe(false);
    expect(isChoreOverdue(null, "2026-07-15", false)).toBe(false);
  });
});
