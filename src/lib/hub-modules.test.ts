import { describe, expect, it } from "vitest";
import {
  DEFAULT_HUB_MODULES,
  mergeHubModules,
  parseHubModules,
  serializeHubModules,
} from "./hub-modules";

describe("parseHubModules", () => {
  it("returns defaults for empty input", () => {
    expect(parseHubModules("")).toEqual(DEFAULT_HUB_MODULES);
    expect(parseHubModules(undefined)).toEqual(DEFAULT_HUB_MODULES);
  });

  it("merges partial stored values", () => {
    expect(
      parseHubModules(
        serializeHubModules({
          routines: false,
          chores: true,
          snacks: false,
          recipes: true,
        }),
      ),
    ).toEqual({
      routines: false,
      chores: true,
      snacks: false,
      recipes: true,
    });
  });

  it("falls back to defaults for invalid json", () => {
    expect(parseHubModules("{not json")).toEqual(DEFAULT_HUB_MODULES);
  });
});

describe("mergeHubModules", () => {
  it("fills missing keys from defaults", () => {
    expect(mergeHubModules({ routines: false })).toEqual({
      ...DEFAULT_HUB_MODULES,
      routines: false,
    });
  });
});
