"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireUser } from "@/lib/household";
import {
  DEFAULT_HUB_MODULES,
  HUB_MODULE_IDS,
  type HubModules,
} from "@/lib/hub-modules";
import { saveUserHubModules } from "@/lib/hub-modules-store";

const hubModulesSchema = z.object({
  routines: z.boolean(),
  chores: z.boolean(),
  snacks: z.boolean(),
  recipes: z.boolean(),
});

export async function saveHubModules(input: Partial<HubModules>) {
  const user = await requireUser();
  const parsed = hubModulesSchema.partial().parse(input);
  const next = await saveUserHubModules(user.id, parsed);

  revalidatePath("/", "layout");
  for (const id of HUB_MODULE_IDS) {
    if (id === "routines") revalidatePath("/routines");
    if (id === "chores") revalidatePath("/chores");
    if (id === "snacks") revalidatePath("/meals/snacks");
    if (id === "recipes") revalidatePath("/meals/recipes");
  }

  return next;
}

export async function resetHubModules() {
  return saveHubModules(DEFAULT_HUB_MODULES);
}
