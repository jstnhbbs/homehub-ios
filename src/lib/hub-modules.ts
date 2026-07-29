export const HUB_MODULE_IDS = [
  "routines",
  "chores",
  "snacks",
  "recipes",
] as const;

export type HubModuleId = (typeof HUB_MODULE_IDS)[number];

export type HubModules = Record<HubModuleId, boolean>;

export const DEFAULT_HUB_MODULES: HubModules = {
  routines: true,
  chores: true,
  snacks: true,
  recipes: true,
};

export const HUB_MODULE_LABELS: Record<HubModuleId, string> = {
  routines: "Routines",
  chores: "Chores",
  snacks: "Snacks",
  recipes: "Recipes",
};

export const SIDEBAR_HUB_MODULES: HubModuleId[] = ["routines", "chores"];
export const FOOD_HUB_MODULES: HubModuleId[] = ["snacks", "recipes"];

export function parseHubModules(raw: string | null | undefined): HubModules {
  if (!raw?.trim()) {
    return { ...DEFAULT_HUB_MODULES };
  }

  try {
    const parsed = JSON.parse(raw) as Partial<HubModules>;
    return mergeHubModules(parsed);
  } catch {
    return { ...DEFAULT_HUB_MODULES };
  }
}

export function mergeHubModules(partial: Partial<HubModules>): HubModules {
  return {
    routines: partial.routines ?? DEFAULT_HUB_MODULES.routines,
    chores: partial.chores ?? DEFAULT_HUB_MODULES.chores,
    snacks: partial.snacks ?? DEFAULT_HUB_MODULES.snacks,
    recipes: partial.recipes ?? DEFAULT_HUB_MODULES.recipes,
  };
}

export function serializeHubModules(modules: HubModules): string {
  return JSON.stringify(modules);
}

export function isHubModuleEnabled(
  modules: HubModules,
  module: HubModuleId,
): boolean {
  return modules[module];
}
