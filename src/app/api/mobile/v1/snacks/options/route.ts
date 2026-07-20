import { eq } from "drizzle-orm";
import { z } from "zod";
import { db } from "@/db/client";
import { households } from "@/db/schema";
import {
  handleMobileError,
  mobileJson,
  parseJsonBody,
  serializeHousehold,
  requireMobileHousehold,
  requireMobileParentHousehold,
} from "@/lib/mobile/http";

export async function POST(request: Request) {
  try {
    const household = await requireMobileParentHousehold();
    const { snackOptions } = z
      .object({ snackOptions: z.string().max(2000) })
      .parse(await parseJsonBody(request));

    await db
      .update(households)
      .set({ snackOptions, updatedAt: new Date() })
      .where(eq(households.id, household.id));

    return mobileJson(serializeHousehold(await requireMobileHousehold()));
  } catch (error) {
    return handleMobileError(error);
  }
}
