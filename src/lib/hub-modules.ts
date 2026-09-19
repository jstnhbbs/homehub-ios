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

export type HubModuleToggles = Record<HubModuleId, boolean>;

export type HubModules = HubModuleToggles & {
  sidebarOrder: HubModuleId[];
  dashboardCards: Record<DashboardCardId, boolean>;
  dashboardCardSizes: Record<DashboardCardId, DashboardCardSize>;
  dashboardOrder: DashboardCardId[];
};

export type HubModulesInput = Partial<HubModuleToggles> & {
  sidebarOrder?: HubModuleId[];
  dashboardCards?: Partial<Record<DashboardCardId, boolean>>;
  dashboardCardSizes?: Partial<Record<DashboardCardId, DashboardCardSize>>;
  dashboardOrder?: DashboardCardId[];
};

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
  dashboardCardSizes: {
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
  },
  dashboardOrder: [
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
  ],
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
};

function migrateLegacyId(id: string): string {
  return id === "shopping" ? "groceries" : id;
}

function migrateLegacyPartial(partial: LegacyHubModulesInput): HubModulesInput {
  const { shopping, ...rest } = partial;
  return {
    ...rest,
    groceries: partial.groceries ?? shopping,
    sidebarOrder: partial.sidebarOrder?.map((id) => migrateLegacyId(id) as HubModuleId),
    dashboardOrder: partial.dashboardOrder?.map(
      (id) => migrateLegacyId(id) as DashboardCardId,
    ),
    dashboardCards: partial.dashboardCards
      ? Object.fromEntries(
          Object.entries(partial.dashboardCards).map(([key, value]) => [
            migrateLegacyId(key),
            value,
          ]),
        )
      : undefined,
    dashboardCardSizes: partial.dashboardCardSizes
      ? Object.fromEntries(
          Object.entries(partial.dashboardCardSizes).map(([key, value]) => [
            migrateLegacyId(key),
            value,
          ]),
        )
      : undefined,
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
  const dashboardOrder = normalizeOrder(
    migrated.dashboardOrder,
    DEFAULT_HUB_MODULES.dashboardOrder,
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
    dashboardCardSizes: {
      ...DEFAULT_HUB_MODULES.dashboardCardSizes,
      ...migrated.dashboardCardSizes,
    },
    dashboardOrder,
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
