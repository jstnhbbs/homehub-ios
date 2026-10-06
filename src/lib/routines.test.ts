import { describe, expect, it } from "vitest";
import { normalizeRoutineDays, pairRoutineSteps, routineRunsOn } from "./routines";

describe("routine days", () => {
  it("sorts and de-duplicates the days", () => {
    expect(normalizeRoutineDays("5,1,3,1")).toBe("1,3,5");
    expect(normalizeRoutineDays("0,1,2,3,4,5,6")).toBe("0,1,2,3,4,5,6");
  });

  it("ignores anything that is not a weekday, and refuses when none is left", () => {
    expect(normalizeRoutineDays("1, 9 ,x,3")).toBe("1,3");
    expect(() => normalizeRoutineDays("")).toThrow("at least one day");
    expect(() => normalizeRoutineDays("7,8")).toThrow("at least one day");
  });

  it("says whether a routine runs on a date", () => {
    // 2026-10-05 is a Monday, 2026-10-10 a Saturday.
    expect(routineRunsOn("1,2,3,4,5", "2026-10-05")).toBe(true);
    expect(routineRunsOn("1,2,3,4,5", "2026-10-10")).toBe(false);
    expect(routineRunsOn("0,6", "2026-10-10")).toBe(true);
    expect(routineRunsOn("0,6", "2026-10-11")).toBe(true); // Sunday
    expect(routineRunsOn("0,1,2,3,4,5,6", "2026-12-31")).toBe(true);
  });
});

describe("pairing steps with their rows", () => {
  const rows = [
    { id: "a", label: "Brush teeth" },
    { id: "b", label: "Get dressed" },
    { id: "c", label: "Make bed" },
  ];
  const ids = (incoming: string[]) => pairRoutineSteps(rows, incoming).pairs.map((pair) => pair.id);

  it("keeps every row when nothing changes", () => {
    expect(ids(["Brush teeth", "Get dressed", "Make bed"])).toEqual(["a", "b", "c"]);
  });

  it("moves a step with its row instead of relabelling by position", () => {
    expect(ids(["Make bed", "Brush teeth", "Get dressed"])).toEqual(["c", "a", "b"]);
  });

  it("gives a reworded step the row that nothing else claims", () => {
    expect(ids(["Brush teeth", "Get dressed fast", "Make bed"])).toEqual(["a", "b", "c"]);
  });

  it("adds a new step and removes a dropped one", () => {
    const result = pairRoutineSteps(rows, ["Brush teeth", "Make bed", "Feed the dog"]);
    expect(result.pairs.map((pair) => pair.id)).toEqual(["a", "c", "b"]);
    expect(result.removed).toEqual([]);
    const fewer = pairRoutineSteps(rows, ["Make bed"]);
    expect(fewer.pairs.map((pair) => pair.id)).toEqual(["c"]);
    expect(fewer.removed).toEqual(["a", "b"]);
  });

  it("makes new rows for steps beyond what existed", () => {
    const result = pairRoutineSteps(rows, ["Make bed", "Brush teeth", "Get dressed", "Pack lunch"]);
    expect(result.pairs.map((pair) => pair.id)).toEqual(["c", "a", "b", null]);
  });

  it("copes with the same label twice", () => {
    const twice = [
      { id: "x", label: "Brush teeth" },
      { id: "y", label: "Brush teeth" },
    ];
    expect(pairRoutineSteps(twice, ["Brush teeth", "Brush teeth"]).pairs.map((pair) => pair.id)).toEqual(["x", "y"]);
  });
});
