import { describe, expect, it } from "vitest";
import {
  parseSnackOptions,
  serializeSnackOptions,
  snackEatenLabels,
} from "./snacks";

describe("snack options", () => {
  it("parses newline-separated snack lines", () => {
    expect(parseSnackOptions("Apples\n Yogurt\n\nCheese sticks")).toEqual([
      "Apples",
      "Yogurt",
      "Cheese sticks",
    ]);
  });

  it("serializes snack lines", () => {
    expect(serializeSnackOptions(["Apples", "Yogurt"])).toBe("Apples\nYogurt");
  });
});

describe("which snacks count as eaten", () => {
  const rows = [
    { snackLabel: "Apples", profileId: "" },
    { snackLabel: "Yogurt", profileId: "a" },
    { snackLabel: "Yogurt", profileId: "b" },
    { snackLabel: "Crackers", profileId: "a" },
    { snackLabel: "Gone", profileId: "deleted-child" },
  ];

  it("household-wide mode uses only the shared rows", () => {
    expect(snackEatenLabels(rows, false, ["a", "b"])).toEqual(["Apples"]);
  });

  it("per-child mode needs every child to have had it", () => {
    expect(snackEatenLabels(rows, true, ["a", "b"])).toEqual(["Yogurt"]);
  });

  it("per-child mode with one child counts that child's snacks", () => {
    expect(snackEatenLabels(rows, true, ["a"]).sort()).toEqual(["Crackers", "Yogurt"]);
  });

  it("ignores rows for a child who has been deleted", () => {
    expect(snackEatenLabels(rows, true, ["a", "b"])).not.toContain("Gone");
  });

  it("per-child mode with no children counts nothing, rather than everything", () => {
    expect(snackEatenLabels(rows, true, [])).toEqual([]);
  });

  it("does not repeat a label", () => {
    const twice = [
      { snackLabel: "Apples", profileId: "" },
      { snackLabel: "Apples", profileId: "" },
    ];
    expect(snackEatenLabels(twice, false, [])).toEqual(["Apples"]);
  });
});
