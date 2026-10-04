import { describe, expect, it } from "vitest";
import {
  DEFAULT_HUB_MODULES,
  dashboardCardSizesFor,
  dashboardOrderFor,
  mergeHubModules,
  parseHubModules,
  serializeHubModules,
  type HubModulesInput,
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

  it("preserves reordered dashboard cards including weather, per device", () => {
    const phoneOrder = [
      "schedule",
      "routines",
      "weather",
      "chores",
      "meals",
      "snacks",
      "sleep",
      "groceries",
    ] as const;
    const tabletOrder = ["birthdays", "weather", "notes"] as const;

    const serialized = serializeHubModules({
      dashboardCards: { weather: false, routines: true },
      dashboardOrderPhone: [...phoneOrder],
      dashboardOrderTablet: [...tabletOrder],
    });

    expect(parseHubModules(serialized)).toMatchObject({
      dashboardCards: expect.objectContaining({ weather: false }),
      dashboardOrderPhone: [...phoneOrder, "notes", "birthdays"],
      dashboardOrderTablet: [...tabletOrder, "schedule", "routines", "chores", "meals", "snacks", "sleep", "groceries"],
    });
  });

  it("preserves dashboard card sizes independently per device", () => {
    const serialized = serializeHubModules({
      dashboardCardSizesPhone: { snacks: "expanded" },
      dashboardCardSizesTablet: { snacks: "standard", notes: "expanded" },
    });

    const parsed = parseHubModules(serialized);
    expect(parsed.dashboardCardSizesPhone).toMatchObject({ snacks: "expanded" });
    expect(parsed.dashboardCardSizesTablet).toMatchObject({ snacks: "standard", notes: "expanded" });
  });

  it("maps legacy shopping keys to groceries", () => {
    expect(
      mergeHubModules({
        shopping: false,
        sidebarOrder: ["shopping", "calendar"],
        dashboardCards: { shopping: false },
        dashboardOrderPhone: ["shopping", "weather"],
      } as Parameters<typeof mergeHubModules>[0]),
    ).toMatchObject({
      groceries: false,
      sidebarOrder: expect.arrayContaining(["groceries", "calendar"]),
      dashboardCards: expect.objectContaining({ groceries: false }),
      dashboardOrderPhone: expect.arrayContaining(["groceries", "weather"]),
    });

    expect(
      parseHubModules(
        JSON.stringify({
          shopping: false,
          sidebarOrder: ["calendar", "shopping"],
          dashboardCards: { shopping: false },
          dashboardOrderPhone: ["weather", "shopping"],
        }),
      ),
    ).toMatchObject({
      groceries: false,
      dashboardCards: expect.objectContaining({ groceries: false }),
    });
  });

  describe("data saved before per-device layouts existed", () => {
    // The exact shape found in production before this change: one flat dashboardOrder and
    // dashboardCardSizes, no dashboardCards, no phone/tablet split, and the pre-rename
    // "shopping" key still present.
    const oldFlatWithSizes = JSON.stringify({
      shopping: true,
      sidebarOrder: ["shopping", "calendar"],
      dashboardOrder: ["schedule", "routines", "weather"],
      dashboardCardSizes: { schedule: "expanded", routines: "expanded" },
    });

    // An even older shape: no dashboardCardSizes key at all.
    const oldFlatNoSizes = JSON.stringify({
      sidebarOrder: ["calendar"],
      dashboardOrder: ["weather", "schedule"],
    });

    it("seeds both phone and tablet from the one saved order and sizes", () => {
      const parsed = parseHubModules(oldFlatWithSizes);
      expect(dashboardOrderFor(parsed, "phone")).toEqual(dashboardOrderFor(parsed, "tablet"));
      expect(dashboardCardSizesFor(parsed, "phone")).toEqual(dashboardCardSizesFor(parsed, "tablet"));
      expect(dashboardOrderFor(parsed, "phone").slice(0, 3)).toEqual(["schedule", "routines", "weather"]);
      expect(dashboardCardSizesFor(parsed, "phone")).toMatchObject({ schedule: "expanded", routines: "expanded" });
      // The pre-rename key still migrates the same as it always did.
      expect(parsed.groceries).toBe(true);
    });

    it("falls all the way back to defaults when sizes were never saved at all", () => {
      const parsed = parseHubModules(oldFlatNoSizes);
      expect(dashboardCardSizesFor(parsed, "phone")).toEqual(DEFAULT_HUB_MODULES.dashboardCardSizesPhone);
      expect(dashboardCardSizesFor(parsed, "tablet")).toEqual(DEFAULT_HUB_MODULES.dashboardCardSizesTablet);
      expect(dashboardOrderFor(parsed, "phone").slice(0, 2)).toEqual(["weather", "schedule"]);
    });

    it("lets an explicit phone/tablet value win over the legacy fallback", () => {
      const input = {
        dashboardOrder: ["weather", "schedule"],
        dashboardOrderPhone: ["birthdays", "notes"],
      } as unknown as HubModulesInput;
      const parsed = mergeHubModules(input);
      expect(dashboardOrderFor(parsed, "phone").slice(0, 2)).toEqual(["birthdays", "notes"]);
      // Tablet had no explicit value, so it falls back to the legacy flat order.
      expect(dashboardOrderFor(parsed, "tablet").slice(0, 2)).toEqual(["weather", "schedule"]);
    });
  });
});
