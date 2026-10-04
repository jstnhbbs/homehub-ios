import { z } from "zod";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
} from "@/lib/mobile/http";
import {
  DASHBOARD_CARD_IDS,
  DASHBOARD_CARD_SIZES,
  HUB_MODULE_IDS,
  type HubModulesInput,
  mergeHubModules,
} from "@/lib/hub-modules";
import {
  getUserHubModules,
  saveUserHubModules,
} from "@/lib/hub-modules-store";

const dashboardCardsSchema = z.partialRecord(
  z.enum(DASHBOARD_CARD_IDS),
  z.boolean(),
);

const dashboardCardSizesSchema = z.partialRecord(
  z.enum(DASHBOARD_CARD_IDS),
  z.enum(DASHBOARD_CARD_SIZES),
);

const hubModulesSchema = z.object({
  notes: z.boolean().optional(),
  calendar: z.boolean().optional(),
  groceries: z.boolean().optional(),
  routines: z.boolean().optional(),
  chores: z.boolean().optional(),
  meals: z.boolean().optional(),
  sleep: z.boolean().optional(),
  birthdays: z.boolean().optional(),
  snacks: z.boolean().optional(),
  recipes: z.boolean().optional(),
  sidebarOrder: z.array(z.enum(HUB_MODULE_IDS)).optional(),
  dashboardCards: dashboardCardsSchema.optional(),
  dashboardCardSizesPhone: dashboardCardSizesSchema.optional(),
  dashboardOrderPhone: z.array(z.enum(DASHBOARD_CARD_IDS)).optional(),
  dashboardCardSizesTablet: dashboardCardSizesSchema.optional(),
  dashboardOrderTablet: z.array(z.enum(DASHBOARD_CARD_IDS)).optional(),
});

export async function GET() {
  try {
    const user = await requireMobileUser();
    return mobileJson(await getUserHubModules(user.id));
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function PATCH(request: Request) {
  try {
    const user = await requireMobileUser();
    const input = hubModulesSchema.parse(await parseJsonBody(request));
    const next = await saveUserHubModules(user.id, input as HubModulesInput);
    return mobileJson(next);
  } catch (error) {
    return handleMobileError(error);
  }
}

export async function PUT(request: Request) {
  try {
    const user = await requireMobileUser();
    const input = hubModulesSchema.parse(await parseJsonBody(request));
    const next = await saveUserHubModules(user.id, mergeHubModules(input));
    return mobileJson(next);
  } catch (error) {
    return handleMobileError(error);
  }
}
