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
      ...DEFAULT_HUB_MODULES,
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

  it("preserves reordered dashboard cards including weather", () => {
    const dashboardOrder = [
      "schedule",
      "routines",
      "weather",
      "chores",
      "meals",
      "snacks",
      "sleep",
      "groceries",
    ] as const;

    const serialized = serializeHubModules({
      dashboardCards: { weather: false, routines: true },
      dashboardOrder: [...dashboardOrder],
    });

    expect(parseHubModules(serialized)).toMatchObject({
      dashboardCards: expect.objectContaining({ weather: false }),
      dashboardOrder: [...dashboardOrder, "notes", "birthdays"],
    });
  });

  it("preserves dashboard card sizes", () => {
    const serialized = serializeHubModules({
      dashboardCardSizes: { snacks: "expanded", notes: "standard" },
    });

    expect(parseHubModules(serialized)).toMatchObject({
      dashboardCardSizes: expect.objectContaining({
        snacks: "expanded",
        notes: "standard",
      }),
    });
  });

  it("maps legacy shopping keys to groceries", () => {
    expect(
      mergeHubModules({
        shopping: false,
        sidebarOrder: ["shopping", "calendar"],
        dashboardCards: { shopping: false },
        dashboardOrder: ["shopping", "weather"],
      } as Parameters<typeof mergeHubModules>[0]),
    ).toMatchObject({
      groceries: false,
      sidebarOrder: expect.arrayContaining(["groceries", "calendar"]),
      dashboardCards: expect.objectContaining({ groceries: false }),
      dashboardOrder: expect.arrayContaining(["groceries", "weather"]),
    });

    expect(
      parseHubModules(
        JSON.stringify({
          shopping: false,
          sidebarOrder: ["calendar", "shopping"],
          dashboardCards: { shopping: false },
          dashboardOrder: ["weather", "shopping"],
        }),
      ),
    ).toMatchObject({
      groceries: false,
      dashboardCards: expect.objectContaining({ groceries: false }),
    });
  });
});
