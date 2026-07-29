import { z } from "zod";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  requireMobileUser,
} from "@/lib/mobile/http";
import {
  type HubModules,
  mergeHubModules,
} from "@/lib/hub-modules";
import {
  getUserHubModules,
  saveUserHubModules,
} from "@/lib/hub-modules-store";

const hubModulesSchema = z.object({
  routines: z.boolean().optional(),
  chores: z.boolean().optional(),
  snacks: z.boolean().optional(),
  recipes: z.boolean().optional(),
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
    const next = await saveUserHubModules(user.id, input as Partial<HubModules>);
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
