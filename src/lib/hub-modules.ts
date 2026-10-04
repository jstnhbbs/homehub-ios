export const HUB_MODULE_IDS = [
  "notes",
  "calendar",
  "groceries",
  "routines",
  "chores",
  "meals",
  "sleep",
  "birthdays",
  "snacks",
  "recipes",
] as const;

export type HubModuleId = (typeof HUB_MODULE_IDS)[number];

export const DASHBOARD_CARD_IDS = [
  "weather",
  "schedule",
  "routines",
  "chores",
  "meals",
  "snacks",
  "sleep",
  "groceries",
  "notes",
  "birthdays",
] as const;

export type DashboardCardId = (typeof DASHBOARD_CARD_IDS)[number];

export const DASHBOARD_CARD_SIZES = ["compact", "standard", "expanded"] as const;

export type DashboardCardSize = (typeof DASHBOARD_CARD_SIZES)[number];

/**
 * The dashboard grid is arranged and sized separately for iPhone and for iPad/Mac, since the
 * two have very different amounts of room. (Technically this follows SwiftUI's horizontal size
 * class, so an iPad in a narrow split-screen window uses "phone" too — but for how someone
 * actually uses the app, this is iPhone vs iPad/Mac.)
 */
export const DASHBOARD_LAYOUT_TARGETS = ["phone", "tablet"] as const;

export type DashboardLayoutTarget = (typeof DASHBOARD_LAYOUT_TARGETS)[number];

export type HubModuleToggles = Record<HubModuleId, boolean>;

export type HubModules = HubModuleToggles & {
  sidebarOrder: HubModuleId[];
  /** Which dashboard cards are turned on. Shared: the same set shows on every device. */
  dashboardCards: Record<DashboardCardId, boolean>;
  dashboardCardSizesPhone: Record<DashboardCardId, DashboardCardSize>;
  dashboardOrderPhone: DashboardCardId[];
  dashboardCardSizesTablet: Record<DashboardCardId, DashboardCardSize>;
  dashboardOrderTablet: DashboardCardId[];
};

export type HubModulesInput = Partial<HubModuleToggles> & {
  sidebarOrder?: HubModuleId[];
  dashboardCards?: Partial<Record<DashboardCardId, boolean>>;
  dashboardCardSizesPhone?: Partial<Record<DashboardCardId, DashboardCardSize>>;
  dashboardOrderPhone?: DashboardCardId[];
  dashboardCardSizesTablet?: Partial<Record<DashboardCardId, DashboardCardSize>>;
  dashboardOrderTablet?: DashboardCardId[];
};

const DEFAULT_DASHBOARD_CARD_SIZES: Record<DashboardCardId, DashboardCardSize> = {
  weather: "standard",
  schedule: "standard",
  routines: "standard",
  chores: "standard",
  meals: "standard",
  snacks: "standard",
  sleep: "standard",
  groceries: "standard",
  notes: "standard",
  birthdays: "standard",
};

const DEFAULT_DASHBOARD_ORDER: DashboardCardId[] = [
  "weather",
  "schedule",
  "routines",
  "chores",
  "meals",
  "snacks",
  "sleep",
  "groceries",
  "notes",
  "birthdays",
];

export const DEFAULT_HUB_MODULES: HubModules = {
  notes: true,
  calendar: true,
  groceries: true,
  routines: true,
  chores: true,
  meals: true,
  sleep: true,
  birthdays: true,
  snacks: true,
  recipes: true,
  sidebarOrder: ["notes", "calendar", "groceries", "routines", "chores", "meals", "sleep", "birthdays"],
  dashboardCards: {
    weather: true,
    schedule: true,
    routines: true,
    chores: true,
    meals: true,
    snacks: true,
    sleep: true,
    groceries: true,
    notes: true,
    birthdays: true,
  },
  // Phone and tablet start out identical; they only diverge once someone edits one of them.
  dashboardCardSizesPhone: { ...DEFAULT_DASHBOARD_CARD_SIZES },
  dashboardOrderPhone: [...DEFAULT_DASHBOARD_ORDER],
  dashboardCardSizesTablet: { ...DEFAULT_DASHBOARD_CARD_SIZES },
  dashboardOrderTablet: [...DEFAULT_DASHBOARD_ORDER],
};

export const HUB_MODULE_LABELS: Record<HubModuleId, string> = {
  notes: "Notes",
  calendar: "Calendar",
  groceries: "Groceries",
  routines: "Routines",
  chores: "Chores",
  meals: "Food",
  sleep: "Sleep",
  birthdays: "Birthdays",
  snacks: "Snacks",
  recipes: "Recipes",
};

export const DASHBOARD_CARD_LABELS: Record<DashboardCardId, string> = {
  weather: "Weather",
  schedule: "Today's Schedule",
  routines: "Today's Routines",
  chores: "Chores",
  meals: "Today's Meals",
  snacks: "Snacks",
  sleep: "Sleep",
  groceries: "Groceries",
  notes: "Notes",
  birthdays: "Birthdays",
};

export const SIDEBAR_HUB_MODULES: HubModuleId[] = [
  "notes",
  "calendar",
  "groceries",
  "routines",
  "chores",
  "meals",
  "sleep",
  "birthdays",
];
export const FOOD_HUB_MODULES: HubModuleId[] = ["snacks", "recipes"];

type LegacyHubModulesInput = HubModulesInput & {
  shopping?: boolean;
  /** Pre-per-device-layout shape: one order and one set of sizes shared by every device. */
  dashboardOrder?: DashboardCardId[];
  dashboardCardSizes?: Partial<Record<DashboardCardId, DashboardCardSize>>;
};

function migrateLegacyId(id: string): string {
  return id === "shopping" ? "groceries" : id;
}

function migrateLegacyOrder(order: DashboardCardId[] | undefined): DashboardCardId[] | undefined {
  return order?.map((id) => migrateLegacyId(id) as DashboardCardId);
}

function migrateLegacySizes(
  sizes: Partial<Record<DashboardCardId, DashboardCardSize>> | undefined,
): Partial<Record<DashboardCardId, DashboardCardSize>> | undefined {
  return sizes
    ? Object.fromEntries(
        Object.entries(sizes).map(([key, value]) => [migrateLegacyId(key), value]),
      )
    : undefined;
}

/**
 * Translates old data into the current shape: the "shopping" module rename, and (for anything
 * saved before per-device layouts existed) a single dashboardOrder/dashboardCardSizes seeding
 * both the phone and the tablet layout. Explicit dashboardOrderPhone/Tablet in `partial` always
 * win over the legacy fallback.
 */
function migrateLegacyPartial(partial: LegacyHubModulesInput): HubModulesInput {
  const { shopping, dashboardOrder: legacyOrder, dashboardCardSizes: legacySizes, ...rest } = partial;
  const migratedLegacyOrder = migrateLegacyOrder(legacyOrder);
  const migratedLegacySizes = migrateLegacySizes(legacySizes);

  return {
    ...rest,
    groceries: partial.groceries ?? shopping,
    sidebarOrder: partial.sidebarOrder?.map((id) => migrateLegacyId(id) as HubModuleId),
    dashboardCards: partial.dashboardCards
      ? Object.fromEntries(
          Object.entries(partial.dashboardCards).map(([key, value]) => [
            migrateLegacyId(key),
            value,
          ]),
        )
      : undefined,
    dashboardOrderPhone: migrateLegacyOrder(partial.dashboardOrderPhone) ?? migratedLegacyOrder,
    dashboardOrderTablet: migrateLegacyOrder(partial.dashboardOrderTablet) ?? migratedLegacyOrder,
    dashboardCardSizesPhone: migrateLegacySizes(partial.dashboardCardSizesPhone) ?? migratedLegacySizes,
    dashboardCardSizesTablet: migrateLegacySizes(partial.dashboardCardSizesTablet) ?? migratedLegacySizes,
  };
}

export function parseHubModules(raw: string | null | undefined): HubModules {
  if (!raw?.trim()) {
    return { ...DEFAULT_HUB_MODULES };
  }

  try {
    const parsed = JSON.parse(raw) as LegacyHubModulesInput;
    return mergeHubModules(migrateLegacyPartial(parsed));
  } catch {
    return { ...DEFAULT_HUB_MODULES };
  }
}

export function mergeHubModules(partial: HubModulesInput | LegacyHubModulesInput): HubModules {
  const migrated = migrateLegacyPartial(partial as LegacyHubModulesInput);
  const sidebarOrder = normalizeOrder(
    migrated.sidebarOrder,
    DEFAULT_HUB_MODULES.sidebarOrder,
    SIDEBAR_HUB_MODULES,
  );
  const dashboardOrderPhone = normalizeOrder(
    migrated.dashboardOrderPhone,
    DEFAULT_HUB_MODULES.dashboardOrderPhone,
    DASHBOARD_CARD_IDS,
  );
  const dashboardOrderTablet = normalizeOrder(
    migrated.dashboardOrderTablet,
    DEFAULT_HUB_MODULES.dashboardOrderTablet,
    DASHBOARD_CARD_IDS,
  );

  return {
    notes: migrated.notes ?? DEFAULT_HUB_MODULES.notes,
    calendar: migrated.calendar ?? DEFAULT_HUB_MODULES.calendar,
    groceries: migrated.groceries ?? DEFAULT_HUB_MODULES.groceries,
    routines: migrated.routines ?? DEFAULT_HUB_MODULES.routines,
    chores: migrated.chores ?? DEFAULT_HUB_MODULES.chores,
    meals: migrated.meals ?? DEFAULT_HUB_MODULES.meals,
    sleep: migrated.sleep ?? DEFAULT_HUB_MODULES.sleep,
    birthdays: migrated.birthdays ?? DEFAULT_HUB_MODULES.birthdays,
    snacks: migrated.snacks ?? DEFAULT_HUB_MODULES.snacks,
    recipes: migrated.recipes ?? DEFAULT_HUB_MODULES.recipes,
    sidebarOrder,
    dashboardCards: {
      ...DEFAULT_HUB_MODULES.dashboardCards,
      ...migrated.dashboardCards,
    },
    dashboardCardSizesPhone: {
      ...DEFAULT_HUB_MODULES.dashboardCardSizesPhone,
      ...migrated.dashboardCardSizesPhone,
    },
    dashboardOrderPhone,
    dashboardCardSizesTablet: {
      ...DEFAULT_HUB_MODULES.dashboardCardSizesTablet,
      ...migrated.dashboardCardSizesTablet,
    },
    dashboardOrderTablet,
  };
}

export function serializeHubModules(modules: HubModulesInput): string {
  return JSON.stringify(mergeHubModules(modules));
}

export function isHubModuleEnabled(
  modules: HubModules,
  module: HubModuleId,
): boolean {
  return modules[module];
}

export function dashboardOrderFor(modules: HubModules, target: DashboardLayoutTarget): DashboardCardId[] {
  return target === "phone" ? modules.dashboardOrderPhone : modules.dashboardOrderTablet;
}

export function dashboardCardSizesFor(
  modules: HubModules,
  target: DashboardLayoutTarget,
): Record<DashboardCardId, DashboardCardSize> {
  return target === "phone" ? modules.dashboardCardSizesPhone : modules.dashboardCardSizesTablet;
}

function normalizeOrder<T extends string>(
  candidate: readonly T[] | undefined,
  fallback: readonly T[],
  allowed: readonly T[],
): T[] {
  const allowedSet = new Set<T>(allowed);
  const seen = new Set<T>();
  const normalized: T[] = [];
  for (const item of candidate ?? []) {
    if (allowedSet.has(item) && !seen.has(item)) {
      normalized.push(item);
      seen.add(item);
    }
  }
  for (const item of fallback) {
    if (!seen.has(item)) {
      normalized.push(item);
      seen.add(item);
    }
  }
  return normalized;
}
